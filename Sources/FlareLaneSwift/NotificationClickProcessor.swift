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
}
