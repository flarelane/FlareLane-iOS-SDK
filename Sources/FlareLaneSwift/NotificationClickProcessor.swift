//
//  NotificationClickProcessor.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

@available(iOSApplicationExtension, unavailable)
@objc public class NotificationClickProcessor: NSObject {

  @objc public static let shared = NotificationClickProcessor()

  /// Process notification click with duplicate prevention, deep link handling, and click handler execution
  /// - Parameter notification: Received notification
  @objc public func processNotificationClick(notification: FlareLaneNotification) {
    // Gate on the shared dedup cache so a re-fire of the same CLICKED event
    // (rapid re-tap, OS replay, etc.) skips backend POST + handler invoke
    // together. RECEIVED events for the same notification id remain independent
    // because the dedup key is `<id>#<eventType>`.
    if !NotificationEventDedup.shouldProcess(notificationId: notification.id, eventType: "CLICKED") {
      Logger.verbose("Duplicate notification CLICKED processing prevented: \(notification.id)")
      return
    }

    Logger.verbose("Clicked user notification: \(notification.id)")

    // Send clicked event
    EventService.createClicked(notification: notification)

    // Handle deep link URL if present
    if !shouldDismissDeepLink(notification: notification) {
      handleDeepLink(notification: notification)
    }

    // Execute click handler
    executeClickHandler(notification: notification)
  }

  // MARK: Private Methods

  private func shouldDismissDeepLink(notification: FlareLaneNotification) -> Bool {
    // Check Info.plist setting
    if let infoDictionary = Bundle.main.infoDictionary,
       let flarelane_dismiss_launch_url = infoDictionary["flarelane_dismiss_launch_url"] as? Bool, flarelane_dismiss_launch_url == true {
      Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url in Info.plist is YES.")
      return true
    }

    // Check notification data setting
    if let flarelane_dismiss_launch_url = notification.data?["flarelane_dismiss_launch_url"] as? String, flarelane_dismiss_launch_url == "true" {
      Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url is true.")
      return true
    }

    return false
  }

  private func handleDeepLink(notification: FlareLaneNotification) {
    // `clickedUrl` already picks the right source — button.link for button clicks, body url
    // for body clicks, nil when neither is set. No extra fallback needed here.
    guard let urlString = notification.clickedUrl, let url = URL(string: urlString) else { return }
    Logger.verbose("Processing deep link for notification: \(notification.id)")
    FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
  }

  private func executeClickHandler(notification: FlareLaneNotification) {
    guard let clickedHandler = EventHandlers.notificationClicked else {
      Logger.verbose("unhandledNotification saved")
      // If notificationClicked handler is nil, the last notification is saved and executed when the handler is registered.
      EventHandlers.unhandledNotification = notification
      return
    }

    Logger.verbose("clickedHandler found, execute handler")
    clickedHandler(notification)
  }

  /// Clear processed notification tracking cache (useful for testing). Kept as a
  /// public API for backward compatibility; dedup state lives in [NotificationEventDedup].
  @objc public static func clearProcessedNotificationIds() {
    NotificationEventDedup.clearForTesting()
    Logger.verbose("Cleared processed notification keys cache")
  }
}
