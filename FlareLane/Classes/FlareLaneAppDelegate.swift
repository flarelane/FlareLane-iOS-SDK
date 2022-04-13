//
//  FlareLaneAppDelegate.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
class FlareLaneAppDelegate {
  
  static let shared = FlareLaneAppDelegate()
  
  func swizzle() {
    guard Globals.swizzled == false else {
      Logger.error("Already swizzled.")
      return
    }
    
    Logger.verbose("Start swizzle UIApplicationDelegate.")
    self.swizzleDidRegisterForRemoteNotificationsWithDeviceToken()
    self.swizzleDidFailToRegisterForRemoteNotificationsWithError()
    self.swizzleDidReceiveRemoteNotification()
    Logger.verbose("Succeed swizzling")
  }
  
  // MARK: - Swizzler
  
  private func swizzleDidRegisterForRemoteNotificationsWithDeviceToken() {
    Logger.verbose("Start swizzleDidRegisterForRemoteNotificationsWithDeviceToken")
    let appDelegate = UIApplication.shared.delegate
    let appDelegateClass: AnyClass? = object_getClass(appDelegate)
    
    let originalSelector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
    let swizzledSelector = #selector(
      FlareLaneAppDelegate.self.flarelane_application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
    
    guard let swizzledMethod = class_getInstanceMethod(
            FlareLaneAppDelegate.self, swizzledSelector) else {
      Logger.error("Failed swizzleDidRegisterForRemoteNotificationsWithDeviceToken")
      return
    }
    
    if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector)  {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    } else {
      class_addMethod(appDelegateClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    }
  }
  
  private func swizzleDidReceiveRemoteNotification() {
    Logger.verbose("Start swizzleDidReceiveRemoteNotification")
    let appDelegate = UIApplication.shared.delegate
    let appDelegateClass: AnyClass? = object_getClass(appDelegate)
    
    let originalSelector = #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    let swizzledSelector = #selector(
      FlareLaneAppDelegate.self.flarelane_application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    
    guard let swizzledMethod = class_getInstanceMethod(
            FlareLaneAppDelegate.self, swizzledSelector) else {
      Logger.error("Failed swizzleDidReceiveRemoteNotification")
      return
    }
    
    if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector)  {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    } else {
      class_addMethod(appDelegateClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    }
  }
  
  private func swizzleDidFailToRegisterForRemoteNotificationsWithError() {
    Logger.verbose("Start swizzleDidFailToRegisterForRemoteNotificationsWithError")
    let appDelegate = UIApplication.shared.delegate
    let appDelegateClass: AnyClass? = object_getClass(appDelegate)
    
    let originalSelector = #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:))
    let swizzledSelector = #selector(
      FlareLaneAppDelegate.self.flarelane_application(_:didFailToRegisterForRemoteNotificationsWithError:))
    
    guard let swizzledMethod = class_getInstanceMethod(
            FlareLaneAppDelegate.self, swizzledSelector) else {
      Logger.error("Failed swizzleDidFailToRegisterForRemoteNotificationsWithError")
      return
    }
    
    if let originalMethod = class_getInstanceMethod(appDelegateClass, originalSelector)  {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    } else {
      class_addMethod(appDelegateClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
    }
  }
  
  // MARK: - Swizzle Methods
  
  @objc func flarelane_application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Logger.verbose("Start register for remote notifications.")
    
    // Convert token to string
    let pushToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
    Logger.verbose("APNs device token: \(pushToken)")
    
    guard let projectId = Globals.projectId else {
      return
    }
    
    // It is divided into activate and register depending on the presence of deviceId
    if let deviceId = Globals.deviceIdInUserDefaults {
      DeviceService.activate(deviceId: deviceId, pushToken: pushToken)
    } else {
      DeviceService.register(projectId: projectId, pushToken: pushToken)
    }
  }
  
  @objc func flarelane_application(_ application: UIApplication,
                                   didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // From version 10 or later, notificationCenter has a higher priority
    completionHandler(UIBackgroundFetchResult.newData)
  }
  
  @objc func flarelane_application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    Logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
}
