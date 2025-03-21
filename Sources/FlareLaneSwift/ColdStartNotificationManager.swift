//
//  ColdStartNotificationManager.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
class ColdStartNotificationManager {
  static var coldStartNotification: FlareLaneNotification?
  
  /// Set coldStartNotification in launchOptions
  /// - Parameter launchOptions: AppDelegate didFinishLaunchingWithOptions
  static func setColdStartNotification(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromLaunchOptions(launchOptions: launchOptions) {
      self.coldStartNotification = flarelaneNotification
    }
  }
  
  /// Check and execute coldStartNotification
  static func process() {
    guard let notification = coldStartNotification else {
      return
    }
    
    if (UIApplication.shared.applicationState == .background) {
      // When called in the background, the app is not turned on
      // Set coldStartNotification to null to be clicked in notificationCenter
      self.coldStartNotification = nil
    } else {
      // If it is not in the background state, process clicked and keep coldStartNotification to avoid duplicate processing in notificationCenter
      EventService.createClicked(notification: notification)
    }
  }
}
