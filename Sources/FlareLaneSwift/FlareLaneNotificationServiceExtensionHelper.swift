//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UserNotifications
import MobileCoreServices

/// The two UNUserNotificationCenter calls the action-button path depends on, extracted so the
/// registration sequencing can be unit tested with a fake center. The completion must be
/// @Sendable to match UNUserNotificationCenter's own signature (an error in Swift 6 otherwise).
protocol NotificationCategoryStore {
  func getNotificationCategories(completionHandler: @escaping @Sendable (Set<UNNotificationCategory>) -> Void)
  func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

extension UNUserNotificationCenter: NotificationCategoryStore {}

/// The two media fetches the NSE performs, extracted so didReceive's download sequencing can be
/// unit tested with a fake downloader (same seam pattern as NotificationCategoryStore).
protocol NotificationMediaDownloader {
  /// Download the big-picture image and wrap it as a notification attachment.
  func downloadAttachment(from url: URL, completion: @escaping @Sendable (UNNotificationAttachment?) -> Void)
  /// Download raw data (sender avatar).
  func downloadData(from url: URL, completion: @escaping @Sendable (Data?) -> Void)
}

final class URLSessionMediaDownloader: NotificationMediaDownloader {
  /// Bounds every fetch so a slow CDN can never eat the NSE's ~30s budget; on timeout the
  /// notification is still delivered — just without the image or chat styling.
  static let resourceTimeout: TimeInterval = 10

  private let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForResource = URLSessionMediaDownloader.resourceTimeout
    return URLSession(configuration: configuration)
  }()

  func downloadAttachment(from url: URL, completion: @escaping @Sendable (UNNotificationAttachment?) -> Void) {
    let task = session.downloadTask(with: url) { downloadedUrl, response, error in
      // The temp file is only valid inside this callback, so the attachment (which takes
      // ownership of the file) must be created here.
      guard let downloadedUrl = downloadedUrl,
            let attachment = try? UNNotificationAttachment(identifier: "flarelane_notification_attachment",
                                                           url: downloadedUrl,
                                                           options: [UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG]) else {
        completion(nil)
        return
      }
      completion(attachment)
    }
    task.resume()
  }

  /// Hard cap on the avatar payload — anything larger falls back to a normal notification
  /// (guides recommend a square image under 1MB; 5MB is the safety ceiling).
  static let maxAvatarBytes = 5 * 1024 * 1024

  func downloadData(from url: URL, completion: @escaping @Sendable (Data?) -> Void) {
    // downloadTask streams the body to disk (same as the attachment path above), so an
    // oversized payload never sits in RAM — the NSE gets jetsammed around ~24MB, and a
    // dataTask would buffer the whole response in memory before we could check its size.
    let task = session.downloadTask(with: url) { downloadedUrl, response, error in
      guard error == nil,
            let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode),
            let downloadedUrl = downloadedUrl else {
        completion(nil)
        return
      }

      // Reject clearly-wrong payloads (HTML error pages, JSON) while tolerating CDNs that omit
      // the header or serve images as generic octet-streams. Header lookup API requires iOS 13;
      // the caller only fetches avatars on iOS 15+, so the else-branch is unreachable in practice.
      if #available(iOS 13.0, *) {
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
           contentType.isEmpty == false,
           contentType.hasPrefix("image/") == false,
           contentType.contains("octet-stream") == false {
          completion(nil)
          return
        }
      }

      // Size gate BEFORE loading into memory; the temp file is only valid inside this callback.
      guard let fileSize = (try? FileManager.default.attributesOfItem(atPath: downloadedUrl.path)[.size] as? NSNumber)?.intValue,
            fileSize > 0,
            fileSize <= URLSessionMediaDownloader.maxAvatarBytes,
            let data = try? Data(contentsOf: downloadedUrl) else {
        completion(nil)
        return
      }

      completion(data)
    }
    task.resume()
  }
}

@objc public class FlareLaneNotificationServiceExtensionHelper: NSObject {
  @objc public static let shared = FlareLaneNotificationServiceExtensionHelper()

  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?

  /// Injectable for tests; production always uses the URLSession-backed downloader.
  var mediaDownloader: NotificationMediaDownloader = URLSessionMediaDownloader()

  /// Holder the @Sendable download completions write into; the DispatchGroup orders both
  /// writes before the notify-block read, so no locking is needed.
  private final class MediaResults: @unchecked Sendable {
    var attachment: UNNotificationAttachment?
    var avatarData: Data?
  }

  /// One-shot latch so the download-completion path and serviceExtensionTimeWillExpire can never
  /// both hand content to the OS for the same delivery (the second call would be dropped by iOS
  /// with a warning, but racing it is sloppy). Lock-guarded because expire and the download
  /// group's notify run on different queues.
  private final class DeliveryGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var delivered = false
    func claim() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      if delivered { return false }
      delivered = true
      return true
    }
  }
  
  @objc public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    // The extension is its own process and is reused across deliveries, so adopt the level the
    // app last set. Falls back to the default when the app never set one.
    Globals.logLevel = Globals.logLevelInUserDefaults.flatMap { LogLevel(rawValue: $0) } ?? .verbose
    Logger.verbose("INVOKED")

    // Every delivery path (guard exits, download completion, expiration fallback) goes through
    // this wrapper so contentHandler runs exactly once per delivery.
    let guardState = DeliveryGuard()
    let deliver: (UNNotificationContent) -> Void = { content in
      guard guardState.claim() else { return }
      contentHandler(content)
    }

    self.contentHandler = deliver
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    
    if let badgeCount = bestAttemptContent?.badge as? Int {
      BadgeManager.setCount(badgeCount)
    } else {
      BadgeManager.setCount(BadgeManager.getCount() + 1)
    }
    
    guard let bestAttemptContent = bestAttemptContent,
          let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) else {
      deliver(self.bestAttemptContent ?? request.content)
      return
    }
    
    // Thread the notification as early as possible so even the serviceExtensionTimeWillExpire
    // fallback delivers grouped content. The server also sets aps.thread-id (the primary
    // mechanism, which works without an NSE); this mirror only fills the gap when a payload
    // carries threadId without it, and never overrides a server-set value.
    if bestAttemptContent.threadIdentifier.isEmpty, let threadId = flarelaneNotification.threadId {
      bestAttemptContent.threadIdentifier = threadId
    }

    // Only Background. Cannot split background~foreground in extension.
    EventService.createBackgroundReceived(notificationId: flarelaneNotification.id)

    // Register a per-notification UNNotificationCategory carrying this push's action buttons.
    // This BLOCKS until the OS has the category (bounded by 2x categoryFetchTimeout, well within
    // the NSE's ~30s budget): once contentHandler runs the NSE can be suspended at any moment,
    // and a category that is still pending registration is never applied — the notification then
    // shows without buttons (reported on iOS 16, image-less pushes being the tightest window).
    registerActionButtonsIfNeeded(notification: flarelaneNotification, content: bestAttemptContent)

    // Download the big-picture image and the sender avatar concurrently; with neither present
    // the group is empty and notify fires immediately. Worst case adds one bounded resource
    // timeout (10s) on top of the category waits — still inside the NSE budget.
    let downloadGroup = DispatchGroup()
    let results = MediaResults()

    if let imageUrl = flarelaneNotification.imageUrl, let attachmentUrl = URL(string: imageUrl) {
      downloadGroup.enter()
      mediaDownloader.downloadAttachment(from: attachmentUrl) { attachment in
        results.attachment = attachment
        downloadGroup.leave()
      }
    }

    // The avatar is only consumed by the iOS 15+ communication restyle below — skip the
    // download entirely on older versions instead of fetching data that would be discarded.
    if #available(iOS 15.0, *),
       let avatarUrl = flarelaneNotification.communication?.senderImageUrl, let url = URL(string: avatarUrl) {
      downloadGroup.enter()
      mediaDownloader.downloadData(from: url) { data in
        results.avatarData = data
        downloadGroup.leave()
      }
    }

    downloadGroup.notify(queue: .global()) {
      if let attachment = results.attachment {
        bestAttemptContent.attachments = [attachment]
      }

      // The communication restyle must come LAST: updating(from:) returns an immutable copy,
      // so everything set before (category, attachments, threadIdentifier, userInfo) is carried
      // into it, and nothing set after would be. Avatar failure skips the restyle entirely —
      // a normal app-icon notification beats a chat bubble with a broken gray monogram.
      var finalContent: UNNotificationContent = bestAttemptContent
      if #available(iOS 15.0, *), let communication = flarelaneNotification.communication {
        finalContent = FlareLaneCommunicationIntentBuilder.apply(
          communication: communication,
          notificationId: flarelaneNotification.id,
          threadId: flarelaneNotification.threadId,
          avatarData: results.avatarData,
          to: bestAttemptContent
        )
      }

      deliver(finalContent)
    }
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

    // Besides evicted IDs, drop any stale category sharing this identifier: Set.insert is a
    // no-op when an equal member already exists, and a repeated notification ID must replace
    // its previous category so updated actions win.
    var merged = Set(existing.filter { !evicted.contains($0.identifier) && $0.identifier != category.identifier })
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
    let box = CategoriesBox()
    store.getNotificationCategories { categories in
      box.value = categories
      semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + timeout) == .success else { return nil }
    return box.value
  }

  /// Mutable holder a @Sendable completion can write into (a captured `var` cannot be mutated
  /// there). The semaphore orders the write before the read, so no locking is needed.
  private final class CategoriesBox: @unchecked Sendable {
    var value: Set<UNNotificationCategory>?
  }
}
