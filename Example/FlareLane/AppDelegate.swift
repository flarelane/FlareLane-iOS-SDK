//
//  AppDelegate.swift
//  FlareLane
//
//  Created by FlareLane on 09/24/2021.
//  Copyright (c) 2021 FlareLane. All rights reserved.
//

import UIKit
import FlareLane
import OneSignal

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  
  var window: UIWindow?
  private let FLARELANE_PROJECT_ID = "FLARELANE_PROJECT_ID"
  private let ONESIGNAL_APP_ID = "ONESIGNAL_APP_ID"
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    // Initialize by setting logLevel and projectId.
    FlareLane.setLogLevel(level: .verbose)
    FlareLane.initWithLaunchOptions(launchOptions, projectId: FLARELANE_PROJECT_ID)
    FlareLane.setNotificationConvertedHandler() { payload in
      // Do something...
      print(payload)
    }
    
    OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
    OneSignal.initWithLaunchOptions(launchOptions)
    OneSignal.setAppId(ONESIGNAL_APP_ID)
    OneSignal.promptForPushNotifications(userResponse: { accepted in
      print("User accepted notifications: \(accepted)")
    })
    
    UNUserNotificationCenter.current().delegate = self
    
    return true
  }
  
  // If you are not swizzled, must input this matched methods.
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    FlareLaneAppDelegate.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    FlareLaneNotificationCenter.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    FlareLaneNotificationCenter.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}

