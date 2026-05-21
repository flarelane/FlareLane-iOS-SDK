//
//  NotificationClickProcessor.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

/// Backward-compatible entry point preserved for callers that historically invoked
/// `NotificationClickProcessor.shared.processNotificationClick(notification:)`.
///
/// The full click pipeline (dedup → server event → deep link → handler) now lives in
/// `EventService.createClicked(notification:)`. This class simply forwards.
@available(iOSApplicationExtension, unavailable)
@objc public class NotificationClickProcessor: NSObject {

  @objc public static let shared = NotificationClickProcessor()

  /// Process a notification click. Delegates to `EventService.createClicked`, which handles
  /// duplicate prevention internally via `EventDeduplicator`.
  /// - Parameter notification: Received notification
  @objc public func processNotificationClick(notification: FlareLaneNotification) {
    Logger.info("Notification", "notification clicked", ["notificationId": notification.id])
    EventService.createClicked(notification: notification)
  }

  /// Deprecated source-compat shim. The earlier SDK exposed this `@objc public` method to clear
  /// an internal `processedNotificationIds: Set<String>` cache (intended for testing). Dedup now
  /// lives in `EventDeduplicator` (process-lifetime, cap-based with automatic wipe at 200), so no
  /// manual clear is necessary and host apps / test code don't need to call this — but keep the
  /// symbol so old call sites continue to compile and ObjC linkage isn't broken.
  @available(*, deprecated, message: "Dedup is now handled automatically by EventDeduplicator (cap-based, process-lifetime). This is a no-op shim kept for source compatibility.")
  @objc public static func clearProcessedNotificationIds() {
    Logger.verbose("Notification", "clearProcessedNotificationIds is a deprecated no-op; dedup runs automatically in EventDeduplicator")
  }
}
