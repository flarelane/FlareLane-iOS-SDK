//
//  FlareLaneNotifiationCenter.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications

class NotificationCenter: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NotificationCenter()
  
  // MARK: - Delegate Methods
  
  /// To handle notification converted
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Logger.verbose("Converted user notification.")
    guard let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotification(notification: response.notification) else {
      return
    }
    
    if (ColdStartNotificationManager.coldStartNotification?.id == notification.id) {
      Logger.verbose("ColdStartNotification is exists. skip didReceive")
      // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
      return
    }
    
    EventService.createConverted(notification: notification)
    
    completionHandler()
  }
  
  /// To handle notification foreground received
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    Logger.verbose("Presented user notification.")
    
    guard let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotification(notification: notification) else {
      return
    }
    
    EventService.createForegroundReceived(notificationId: flarelaneNotification.id)
    
    completionHandler([.alert, .sound])
  }
  
}
