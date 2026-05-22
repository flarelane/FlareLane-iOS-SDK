//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UserNotifications
import MobileCoreServices

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
    // The OS resolves `categoryIdentifier` lazily at presentation time, so it's safe to register
    // alongside the (potentially slower) image download below — by the time the OS reads it,
    // setNotificationCategories has run.
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

    content.categoryIdentifier = categoryIdentifier

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
    defaults.set(tracked, forKey: Self.registeredCategoriesKey)

    // Merge into the existing category set so we don't clobber categories registered by the host
    // app or other libraries, while dropping any of ours we just evicted from the tracked list.
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { existing in
      let filtered = existing.filter { !evicted.contains($0.identifier) }
      var merged = filtered
      merged.insert(category)
      center.setNotificationCategories(merged)
    }
  }
}
