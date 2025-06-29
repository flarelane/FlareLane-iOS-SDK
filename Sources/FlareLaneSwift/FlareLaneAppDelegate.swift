//
//  FlareLaneAppDelegate.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneAppDelegate: NSObject {
  
  @objc public static let shared = FlareLaneAppDelegate()
  
  // MARK: - Methods
  
  @objc public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    
    FlareLane.hasPermissionForNotifications { hasPermission in
      if hasPermission {
        FlareLaneTaskManager.shared.addTaskAfterInit(taskName: "didRegisterForRemoteNotificationsWithDeviceToken") { completionTask in
          // Convert token to string
          let newPushToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
          Logger.verbose("APNs device token: \(newPushToken)")
          
          // 기존 토큰과 비교하여 다를 경우에만 업데이트
          if Globals.pushTokenInUserDefaults != newPushToken {
            Globals.pushTokenInUserDefaults = newPushToken
            
            DeviceService.update(body: ["pushToken": newPushToken, "notificationPermission": hasPermission]) { _ in
              completionTask()
            }
          } else {
            completionTask()
          }
        }
      }
    }
  }
  
}
