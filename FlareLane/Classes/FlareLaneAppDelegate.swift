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

  func swizzle() {
    guard Globals.swizzled == false else {
      Logger.error("Already swizzled.")
      return
    }

    Logger.verbose("Start swizzle UIApplicationDelegate.")
    self.swizzleDidRegisterForRemoteNotificationsWithDeviceToken()
    Logger.verbose("Succeed swizzling")
  }

  // MARK: - Swizzler

  private func swizzleDidRegisterForRemoteNotificationsWithDeviceToken() {
    Logger.verbose("Start swizzleDidRegisterForRemoteNotificationsWithDeviceToken")
    let appDelegate = UIApplication.shared.delegate
    let appDelegateClass: AnyClass? = object_getClass(appDelegate)

    let originalSelector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
    let swizzledSelector = #selector(
      FlareLaneAppDelegate.self.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))

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

  // MARK: - Swizzle Methods

  @objc public func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    guard let _ = Globals.projectId else {
      return
    }

    // Convert token to string
    let prevPushToken = Globals.pushTokenInUserDefaults
    let pushToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
    Logger.verbose("APNs device token: \(pushToken)")
    
    // It is divided into activate and register depending on the presence of deviceId
    if let deviceId = Globals.deviceIdInUserDefaults, pushToken != prevPushToken {
      let body = ["pushToken": pushToken]
      
      DeviceService.update(deviceId: deviceId, body: body) { _ in
        Globals.pushTokenInUserDefaults = pushToken
      }
    }
  }
}
