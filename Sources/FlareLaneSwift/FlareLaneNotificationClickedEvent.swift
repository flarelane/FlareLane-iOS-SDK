//
//  FlareLaneNotificationClickedEvent.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Mirror of `FlareLaneNotificationReceivedEvent` for the click path: wraps a notification (with
/// any tapped-button index already baked in) and exposes `process()` to run the click pipeline
/// (CLICKED event + deep link + click handler).
///
/// The public click handler signature passes the underlying `FlareLaneNotification` directly —
/// callers read `notification.clickedButton`, `notification.clickedUrl`, etc. on that. This
/// wrapper exists so the internal processing pipeline has a single object to thread through.
@available(iOSApplicationExtension, unavailable)
@objc open class FlareLaneNotificationClickedEvent: NSObject {
  @objc public let notification: FlareLaneNotification

  @objc public init(notification: FlareLaneNotification) {
    self.notification = notification
  }

  /// Run the click pipeline (dedup → CLICKED event → deep link → click handler).
  @objc public func process() {
    NotificationClickProcessor.shared.processNotificationClick(notification: notification)
  }
}
