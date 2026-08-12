//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UserNotifications
import MobileCoreServices

/// The two UNUserNotificationCenter calls the action-button path depends on, extracted so the
/// registration sequencing can be unit tested with a fake center.
protocol NotificationCategoryStore {
  func getNotificationCategories(completionHandler: @escaping (Set<UNNotificationCategory>) -> Void)
  func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

extension UNUserNotificationCenter: NotificationCategoryStore {}

@objc public class FlareLaneNotificationServiceExtensionHelper: NSObject {
  @objc public static let shared = FlareLaneNotificationServiceExtensionHelper()
  
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  
  @objc public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    Logger.verbose("INVOKED")
    
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    
    if let badgeCount = bestAttemptContent?.badge as? Int {
      BadgeManager.setCount(badgeCount)
    } else {
      BadgeManager.setCount(BadgeManager.getCount() + 1)
    }
    
    guard let bestAttemptContent = bestAttemptContent,
          let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) else {
      contentHandler(self.bestAttemptContent ?? request.content)
      return
    }
    
    // Only Background. Cannot split background~foreground in extension.
    EventService.createBackgroundReceived(notificationId: flarelaneNotification.id)

    // Register a per-notification UNNotificationCategory carrying this push's action buttons.
    // This BLOCKS until the OS has the category (bounded by 2x categoryFetchTimeout, well within
    // the NSE's ~30s budget): once contentHandler runs the NSE can be suspended at any moment,
    // and a category that is still pending registration is never applied — the notification then
    // shows without buttons (reported on iOS 16, image-less pushes being the tightest window).
    registerActionButtonsIfNeeded(notification: flarelaneNotification, content: bestAttemptContent)

    guard let imageUrl = flarelaneNotification.imageUrl,
          let attachmentUrl = URL(string: imageUrl) else {
      contentHandler(bestAttemptContent)
      return
    }
    
    let task = URLSession.shared.downloadTask(with: attachmentUrl) { downloadedUrl, response, error in
      defer { contentHandler(bestAttemptContent) }
      
      if let downloadedUrl = downloadedUrl,
         let attachment = try? UNNotificationAttachment(identifier: "flarelane_notification_attachment",
                                                        url: downloadedUrl,
                                                        options: [UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG]) {
        bestAttemptContent.attachments = [attachment]
      }
    }
    
    task.resume()
  }
  
  
  @objc public func serviceExtensionTimeWillExpire() {
    Logger.verbose("INVOKED")
    
    if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
  
  @objc public func isFlareLaneNotification(_ request: UNNotificationRequest) -> Bool {
    if let _ = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) {
      return true
    }

    return false
  }

  // MARK: - Action Buttons

  /// Prefix used for category identifiers FlareLane registers dynamically. Lets us distinguish
  /// our own categories from host-app categories so we never overwrite the latter.
  static let categoryIdentifierPrefix = "flarelane_dynamic_"

  /// Upper bound on how many of our dynamic categories we keep registered with the OS. Each push
  /// with buttons registers one, and they accumulate forever without pruning — devices that go
  /// months between app launches would otherwise grow an unbounded category set. 20 mirrors the
  /// pattern used by other major push SDKs and is far more than any single push needs.
  static let maxDynamicCategories = 20

  /// UserDefaults key tracking our category IDs in insertion order so we can evict the oldest
  /// when the cap is reached. NSE has its own UserDefaults instance, which survives between
  /// invocations as long as the same extension bundle is in use.
  private static let registeredCategoriesKey = "com.flarelane.dynamicCategoryIds"

  /// Max seconds to wait for each UNUserNotificationCenter round-trip during category
  /// registration. Two waits worst case keeps the NSE far inside its ~30s budget, and on
  /// timeout the notification is still delivered — just without buttons.
  static let categoryFetchTimeout: TimeInterval = 5

  /// Build a UNNotificationCategory from the parsed button list and attach its identifier to the
  /// content. Each action's identifier is the button index ("0", "1", ...) so the click handler
  /// can recover `clickedButtonIndex` directly from `response.actionIdentifier`.
  private func registerActionButtonsIfNeeded(notification: FlareLaneNotification, content: UNMutableNotificationContent) {
    guard let buttons = notification.buttons, buttons.isEmpty == false else { return }

    let categoryIdentifier = Self.categoryIdentifierPrefix + notification.id
    let actions: [UNNotificationAction] = buttons.enumerated().map { idx, button in
      // .foreground brings the app to the foreground on tap so the click handler can run
      // normally whether the app was in background or terminated.
      UNNotificationAction(identifier: "\(idx)", title: button.label, options: [.foreground])
    }

    let category = UNNotificationCategory(
      identifier: categoryIdentifier,
      actions: actions,
      intentIdentifiers: [],
      options: []
    )

    // Track our own category IDs in insertion order; when we exceed the cap, the head of the
    // list is the eviction candidate. We re-append the current ID so a repeated notification ID
    // (rare but possible) refreshes its position to the tail. The OS serializes NSE invocations
    // for a single extension instance, so no explicit cross-thread locking is needed here.
    let defaults = UserDefaults.standard
    var tracked = defaults.stringArray(forKey: Self.registeredCategoriesKey) ?? []
    tracked.removeAll { $0 == categoryIdentifier }
    tracked.append(categoryIdentifier)
    var evicted: [String] = []
    while tracked.count > Self.maxDynamicCategories {
      evicted.append(tracked.removeFirst())
    }

    // Attach the identifier only once registration has completed — the content is handed to the
    // OS the moment contentHandler runs, and an identifier pointing at a not-yet-registered
    // category renders without buttons.
    let registered = Self.registerCategorySynchronously(
      category,
      evicted: evicted,
      store: UNUserNotificationCenter.current(),
      timeout: Self.categoryFetchTimeout
    )
    if registered {
      // Persist the tracked list only after the OS actually has the merged set; on failure the
      // previous state stays intact so the next push retries the same eviction consistently.
      defaults.set(tracked, forKey: Self.registeredCategoriesKey)
      content.categoryIdentifier = categoryIdentifier
    }
  }

  /// Register `category` with the notification center, merging into the existing set (so host-app
  /// categories survive) and dropping `evicted` ones, then wait until the OS has committed it.
  /// The whole sequence blocks the caller: read existing -> merge & set -> read back. The final
  /// read acts as a flush barrier — setNotificationCategories has no completion handler, and
  /// without the read-back iOS can present the notification before the category is committed,
  /// so the buttons never appear (same fix OneSignal ships since their iOS 12 report).
  /// Returns true when the caller may attach the category's identifier to the content.
  static func registerCategorySynchronously(
    _ category: UNNotificationCategory,
    evicted: [String],
    store: NotificationCategoryStore,
    timeout: TimeInterval
  ) -> Bool {
    // If this read times out we must not call set at all: setting with an empty merge base
    // would wipe categories registered by the host app or other libraries.
    guard let existing = fetchCategories(from: store, timeout: timeout) else {
      Logger.error("Timed out reading notification categories; delivering push without action buttons")
      return false
    }

    var merged = Set(existing.filter { !evicted.contains($0.identifier) })
    merged.insert(category)
    store.setNotificationCategories(merged)

    if fetchCategories(from: store, timeout: timeout) == nil {
      // Registration was already submitted; deliver with the identifier attached, best effort.
      Logger.error("Timed out flushing notification categories; action buttons may not display")
    }
    return true
  }

  /// Blocking wrapper around getNotificationCategories. Safe to block here: the NSE's didReceive
  /// runs on a system background queue, and UNUserNotificationCenter delivers this completion on
  /// its own internal queue, so waiting on the caller's thread cannot deadlock.
  private static func fetchCategories(from store: NotificationCategoryStore, timeout: TimeInterval) -> Set<UNNotificationCategory>? {
    let semaphore = DispatchSemaphore(value: 0)
    var result: Set<UNNotificationCategory>?
    store.getNotificationCategories { categories in
      result = categories
      semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + timeout) == .success else { return nil }
    return result
  }
}
