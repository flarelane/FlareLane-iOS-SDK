//
//  ColdStartNotificationManager.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class ColdStartNotificationManager {
  static var coldStartNotification: FlareLaneNotification?
  
  /// Set coldStartNotification in launchOptions
  /// - Parameter launchOptions: AppDelegate didFinishLaunchingWithOptions
  static func setColdStartNotification(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    guard let coldStartNotification = launchOptions?[.remoteNotification] as? Dictionary<String, Any>,
          let aps = coldStartNotification["aps"] as? Dictionary<String, Any>,
          let alert = aps["alert"] as? Dictionary<String, Any>,
          let notificationId = coldStartNotification["notificationId"] as? String,
          let body = alert["body"] as? String else {
      
      self.coldStartNotification = nil
      return
    }
    
    let notification = FlareLaneNotification(
      id: notificationId,
      body: body,
      title: alert["title"] as? String,
      url: coldStartNotification["url"] as? String
    )
    
    self.coldStartNotification = notification
  }
  
  /// Check and execute coldStartNotification
  static func process() {
    guard let notification = coldStartNotification else {
      return
    }
    
    if (UIApplication.shared.applicationState == .background) {
      // When called in the background, the app is not turned on
      // Set coldStartNotification to null to be converted in notificationCenter
      self.coldStartNotification = nil
    } else {
      // If it is not in the background state, process converted and keep coldStartNotification to avoid duplicate processing in notificationCenter
      EventService.createConverted(notification: notification)
    }
  }
}
