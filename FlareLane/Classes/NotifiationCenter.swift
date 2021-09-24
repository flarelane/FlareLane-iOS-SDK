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
    
    let notificationData = response.notification.request.content

    guard let notificationId = notificationData.userInfo["notificationId"] as? String else {
      Logger.error("notificationId does not set.")
      return
    }
    
    if (ColdStartNotificationManager.coldStartNotification?.id == notificationId) {
      Logger.verbose("ColdStartNotification is exists. skip didReceive")
      // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
      return
    }
    

    let notification = FlareLaneNotification(
      id: notificationId,
      body: notificationData.body,
      // To avoid unexpected blank lines in place of titles
      title: notificationData.title == "" ? nil : notificationData.title,
      url: notificationData.userInfo["url"] as? String
    )
    
    EventService.createConverted(notification: notification)
    
    completionHandler()
  }
  
  /// To handle notification foreground received
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    Logger.verbose("Presented user notification.")
    
    guard let notificationId = notification.request.content.userInfo["notificationId"] as? String else {
      Logger.error("notificationId does not set.")
      return
    }
    
    EventService.createForegroundReceived(notificationId: notificationId)
    
    completionHandler([.alert, .sound])
  }
  
}
