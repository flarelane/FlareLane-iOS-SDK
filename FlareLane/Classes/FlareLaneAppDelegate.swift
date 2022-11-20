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
  private var registerTokenInvoked = false

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
    guard let projectId = Globals.projectId else {
      return
    }

    Logger.verbose("registerTokenInvoked: \(registerTokenInvoked)")
    if registerTokenInvoked {
      return;
    }
    registerTokenInvoked = true;

    // Convert token to string
    let pushToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
    Logger.verbose("APNs device token: \(pushToken)")

    // It is divided into activate and register depending on the presence of deviceId
    if let deviceId = Globals.deviceIdInUserDefaults {
      DeviceService.activate(deviceId: deviceId, pushToken: pushToken)
    } else {
      DeviceService.register(projectId: projectId, pushToken: pushToken)
    }
  }

}
