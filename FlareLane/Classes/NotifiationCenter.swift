//
//  FlareLaneNotifiationCenter.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications

@available(iOSApplicationExtension, unavailable)
class NotificationCenter: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationCenter()
  
  // MARK: - Delegate Methods
  
  /// To handle notification converted
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Logger.verbose("Converted user notification.")
    
    if let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(response.notification.request.content) {
      if (ColdStartNotificationManager.coldStartNotification?.id == notification.id) {
        Logger.verbose("ColdStartNotification is exists. skip didReceive")
        // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
        return
      }
      
      EventService.createConverted(notification: notification)
    }
    
    completionHandler()
  }
  
  /// To handle notification foreground received
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    Logger.verbose("Presented user notification.")
    
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(notification.request.content) {
      Logger.verbose("notification received: \(flarelaneNotification)")
      EventService.createForegroundReceived(notificationId: flarelaneNotification.id)
    }
    
    completionHandler([.alert, .sound])
  }
  
}
