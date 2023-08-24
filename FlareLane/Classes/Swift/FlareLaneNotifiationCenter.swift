//
//  FlareLaneNotifiationCenter.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
  @objc static public let shared = FlareLaneNotificationCenter()
  
  // MARK: - Delegate Methods
  
  /// To handle notification converted
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Logger.verbose("INVOKED")
    
    if let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(response.notification.request.content) {
      if Globals.projectId == nil {
        Logger.verbose("projectId is nil. Too early clicked? process later when cold start.")
        ColdStartNotificationManager.coldStartNotification = notification
      } else if (ColdStartNotificationManager.coldStartNotification?.id == notification.id) {
        // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
        Logger.verbose("ColdStartNotification is exists. skip didReceive")
      } else {
        Logger.verbose("Converted user notification.")
        EventService.createConverted(notification: notification)
      }
    }
    completionHandler()
  }
  
  /// To handle notification foreground received
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    Logger.verbose("INVOKED")
    
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(notification.request.content) {
      Logger.verbose("notification received: \(flarelaneNotification)")
      EventService.createForegroundReceived(notificationId: flarelaneNotification.id)
    }
    
    completionHandler([.alert, .sound])
  }
  
}
