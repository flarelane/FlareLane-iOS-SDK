//
//  AppDelegate.swift
//  FlareLane
//
//  Created by FlareLane on 09/24/2021.
//  Copyright (c) 2021 FlareLane. All rights reserved.
//

import UIKit
import FlareLane
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

  var window: UIWindow?
  private let FLARELANE_PROJECT_ID = "a43cdc82-0ea5-4fdd-aebc-1940fe99b6c3"
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // FlareLane
    FlareLane.initWithLaunchOptions(launchOptions, projectId: FLARELANE_PROJECT_ID, requestPermissionOnLaunch: false)
    FlareLane.subscribe()
    FlareLane.setTags(tags: ["hello": "123"])
    FlareLane.setTags(tags: ["444": "555"])
    FlareLane.setTags(tags: ["1111": "33333"])
    FlareLane.setTags(tags: ["444222": "4444"])
    FlareLane.setTags(tags: ["3333": "555"])
//    FlareLane.setUserId(userId: "444")
    FlareLane.setNotificationClickedHandler() { payload in
      print(payload)
    }

    FlareLane.setNotificationForegroundReceivedHandler { event in
      if let dismissData = event.notification.data?["dismiss_foreground_notification"] as? String,
         dismissData == "true" {
        return
      }

      event.display()
    }

    FlareLane.setInAppMessageActionHandler { iam, actionId in
      print("setInAppMessageActionHandler: \(iam), \(actionId)")
    }

    // Test with FCM
    UNUserNotificationCenter.current().delegate = self
    FirebaseApp.configure()
    
    let options: UNAuthorizationOptions = [.badge, .alert, .sound]

    UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        } else {
        }
      }
    }

    return true
  }

  // If you are not swizzled, must input this matched methods.
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    FlareLaneAppDelegate.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)

    // Test with FCM
    Messaging.messaging().apnsToken = deviceToken
    Messaging.messaging().token { token, error in
      if let error = error {
        print("Error fetching FCM registration token: \(error)")
      } else if let token = token {
        print("FCM registration token: \(token)")
      }
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    FlareLaneNotificationCenter.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    FlareLaneNotificationCenter.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }
}

