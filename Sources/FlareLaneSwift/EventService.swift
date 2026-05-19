//
//  EventService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class EventService {
  /// Processed when notification is clicked.
  /// Owns the full click pipeline: dedup → server event → deep link → handler.
  /// Marked unavailable in app extensions because deep link / click handler must run in the host app.
  @available(iOSApplicationExtension, unavailable)
  static func createClicked(notification: FlareLaneNotification) {
    sendDedupEvent(
      eventType: "CLICKED",
      notificationId: notification.id,
      dataBuilder: {
        var data: [String: Any] = [:]
        if let button = notification.clickedButton, let idx = notification.clickedButtonIdx {
          data["isButton"] = true
          data["buttonIndex"] = idx
          data["buttonLabel"] = button.label
        }
        if let clickedUrl = notification.clickedUrl, clickedUrl.isEmpty == false {
          data["url"] = clickedUrl
        }
        return data.isEmpty ? nil : data
      },
      afterEmit: {
        if !shouldDismissDeepLink(notification: notification) {
          handleDeepLink(notification: notification)
        }
        executeClickHandler(notification: notification)
      }
    )
  }

  /// Background-received event. Called from the Notification Service Extension process.
  static func createBackgroundReceived(notificationId: String) {
    sendDedupEvent(eventType: "BACKGROUND_RECEIVED", notificationId: notificationId)
  }

  /// Foreground-received event. Called from the host app process.
  static func createForegroundReceived(notificationId: String) {
    sendDedupEvent(eventType: "FOREGROUND_RECEIVED", notificationId: notificationId)
  }

  /// Track an arbitrary user-defined event. Not subject to dedup (callers control their own intent).
  static func trackEvent(type: String, data: [String: Any]?) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }

    API.shared.trackEvent(deviceId: deviceId, type: type, data: data) { (error) in
      if error != nil {
        Logger.error("Failed send event request. \(type)")
        return
      }

      Logger.verbose("Succeed send event request. \(type)")
    }
  }

  // MARK: - Single entry point for SDK-auto events

  /// Dedup-aware emit pipeline shared by all SDK-auto events. Calls `dataBuilder` only after the
  /// dedup check passes, and runs `afterEmit` (e.g. click handler invocation) only when the event
  /// was newly recorded.
  private static func sendDedupEvent(
    eventType: String,
    notificationId: String,
    dataBuilder: (() -> [String: Any]?)? = nil,
    afterEmit: (() -> Void)? = nil
  ) {
    if EventDeduplicator.markAndCheckDuplicate(eventType: eventType, notificationId: notificationId) {
      Logger.verbose("Duplicate \(eventType) prevented: \(notificationId)")
      return
    }
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    Logger.verbose("Send \(eventType) event")
    API.shared.sendEvent(
      deviceId: deviceId,
      type: eventType,
      notificationId: notificationId,
      data: dataBuilder?()
    ) { error in
      if error != nil {
        Logger.error("Failed send event request.")
        return
      }
      Logger.verbose("Succeed send event request.")
    }
    afterEmit?()
  }

  // MARK: - Click-only helpers (host-app process)

  @available(iOSApplicationExtension, unavailable)
  private static func shouldDismissDeepLink(notification: FlareLaneNotification) -> Bool {
    if let infoDictionary = Bundle.main.infoDictionary,
       let flarelane_dismiss_launch_url = infoDictionary["flarelane_dismiss_launch_url"] as? Bool,
       flarelane_dismiss_launch_url == true {
      Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url in Info.plist is YES.")
      return true
    }
    if let flarelane_dismiss_launch_url = notification.data?["flarelane_dismiss_launch_url"] as? String,
       flarelane_dismiss_launch_url == "true" {
      Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url is true.")
      return true
    }
    return false
  }

  @available(iOSApplicationExtension, unavailable)
  private static func handleDeepLink(notification: FlareLaneNotification) {
    // When a button was clicked, prefer the button's link over the notification's base url.
    if let urlString = notification.clickedUrl, let url = URL(string: urlString) {
      Logger.verbose("Processing deep link for notification: \(notification.id)")
      FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
    }
  }

  @available(iOSApplicationExtension, unavailable)
  private static func executeClickHandler(notification: FlareLaneNotification) {
    guard let clickedHandler = EventHandlers.notificationClicked else {
      Logger.verbose("unhandledNotification saved")
      // If notificationClicked handler is nil, the last notification is saved and executed when the handler is registered.
      EventHandlers.unhandledNotification = notification
      return
    }
    Logger.verbose("clickedHandler found, execute handler")
    clickedHandler(notification)
  }
}
