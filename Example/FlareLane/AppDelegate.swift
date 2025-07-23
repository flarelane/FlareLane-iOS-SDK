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
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  private let FLARELANE_PROJECT_ID = "a43cdc82-0ea5-4fdd-aebc-1940fe99b6c3"
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // FlareLane
    FlareLane.initWithLaunchOptions(launchOptions, projectId: FLARELANE_PROJECT_ID, requestPermissionOnLaunch: false)

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

    UNUserNotificationCenter.current().delegate = self

    // Test with FCM
    FirebaseApp.configure()

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
  
  // MARK: - Deep Link Handling
  
  // Handle deep links when app is in background or foreground
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("Deep link received via open URL: \(url)")
    showDeepLinkScreen(url: url.absoluteString)
    return true
  }
  
  // Handle universal links
  func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      print("Universal link received: \(url)")
      showDeepLinkScreen(url: url.absoluteString)
      return true
    }
    return false
  }
  
  // flarelane-example://test?param=value
  private func showDeepLinkScreen(url: String) {
    guard let window = window else { return }
    
     let deepLinkVC = DeepLinkViewController()
     deepLinkVC.deepLinkURL = url
     deepLinkVC.modalPresentationStyle = .fullScreen
    
    // Find the topmost view controller
    var topController = window.rootViewController
    while let presentedController = topController?.presentedViewController {
      topController = presentedController
    }
    
    topController?.present(deepLinkVC, animated: true)
  }
  

  

}

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // FCM Test
    let userInfo = notification.request.content.userInfo
    print(userInfo)
    completionHandler([.alert, .sound])

    FlareLaneNotificationCenter.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    FlareLaneNotificationCenter.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}


