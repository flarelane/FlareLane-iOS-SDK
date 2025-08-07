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

  // Track processed notification IDs to prevent duplicate clicks across different execution paths
  // This prevents issues in React Native where didReceive may be called before process()
  private static var processedNotificationIds: Set<String> = []

  /// Process notification click with duplicate prevention, deep link handling, and click handler execution
  /// - Parameter notification: Received notification
  @objc public func processNotificationClick(notification: FlareLaneNotification) {
    // Check for duplicate prevention
    if NotificationClickProcessor.processedNotificationIds.contains(notification.id) {
      Logger.verbose("Duplicate notification processing prevented: \(notification.id)")
      return
    }

    Logger.verbose("Clicked user notification: \(notification.id)")

    // Mark as processed
    NotificationClickProcessor.processedNotificationIds.insert(notification.id)

    // Clean up old entries to prevent memory leaks (keep only last 1000 entries)
    if NotificationClickProcessor.processedNotificationIds.count > 1000 {
      NotificationClickProcessor.processedNotificationIds.removeAll()
    }

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
    if let urlString = notification.url, let url = URL(string: urlString) {
      Logger.verbose("Processing deep link for notification: \(notification.id)")
      FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
    }
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

  /// Clear processed notification tracking cache (useful for testing)
  @objc public static func clearProcessedNotificationIds() {
    processedNotificationIds.removeAll()
    Logger.verbose("Cleared processed notification IDs cache")
  }
}
