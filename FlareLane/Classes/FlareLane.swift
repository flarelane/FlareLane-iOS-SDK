//
//  FlareLane.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@objc open class FlareLane: NSObject {
  static private var permissionState = PermissionState()
  static private var appDelegate = FlareLaneAppDelegate()
  
  // MARK: - Public Methods
  
  /// Set level to logging
  /// - Parameter level: LogLevel, Default is verbose
  @objc public static func setLogLevel(level: LogLevel) {
    Logger.verbose("Change log level to \(level)")
    Globals.logLevel = level
  }
  
  /// Set sdk type
  /// - Parameter sdkType: e.g. "native"
  /// Must called before initWithLaunchOptions
  public static func setSdkType(sdkType: SdkType) {
    Logger.verbose("Set sdk type to \(sdkType)")
    Globals.sdkType = sdkType
  }
  
  /// Initialize FlareLane SDK
  /// - Parameters:
  ///   - projectId: FlareLane projectId
  ///   - launchOptions: AppDelegate didFinishLaunchingWithOptions
  @objc public static func initWithLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?, projectId: String) {
    Logger.verbose("Start FlareKit initialize.")
    
    if (Globals.projectIdInUserDefaults != projectId) {
      // If the previous projectId and the current projectId are not the same, set deviceId to nil for device creation
      Globals.deviceIdInUserDefaults = nil;
    }
    
    // Set projectId before device is registered
    Globals.projectId = projectId
    
    ColdStartNotificationManager.setColdStartNotification(launchOptions: launchOptions)
    
    UNUserNotificationCenter.current().delegate = NotificationCenter.shared
    
    appDelegate.swizzle()
    
    ColdStartNotificationManager.process()
    
    self.promptForNotifications(completion: { granted in
      if granted {
        UIApplication.shared.registerForRemoteNotifications()
      }
    })
  }
  
  /// Set the handler when notification is converted
  /// - Parameter callback: Handler callback
  @objc public static func setNotificationConvertedHandler(callback: @escaping (FlareLaneNotification) -> Void) {
    Logger.verbose("Set notification converted handler.")
    EventHandlers.notificationConverted = callback
    
    if let unhandledNotification = EventHandlers.unhandledNotification {
      Logger.verbose("found unhandledNotification and execute handler")
      // If the notification is converted before the handler is set, execute the callback once with unhandledNotification and set unhandledNotification to nil.
      callback(unhandledNotification)
      EventHandlers.unhandledNotification = nil
    }
  }
  
  /// Set userId of device
  /// - Parameter userId: userId
  @objc public static func setUserId(userId: String?) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.update(deviceId: deviceId, key: "userId", value: userId)
  }
  
  /// Set tags of device
  /// - Parameter tags: tags
  @objc public static func setTags(tags: [String: Any]) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.update(deviceId: deviceId, key: "tags", value: tags)
  }
  
  /// Delete tags of device
  /// - Parameter keys: Keys to delete
  @objc public static func deleteTags(keys: [String]) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.deleteTags(deviceId: deviceId, keys: keys)
  }
  
  /// Update isSubscribe of device
  /// - Parameter subscribed: subscribed or not
  @objc public static func setIsSubscribed(isSubscribed: Bool) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.update(deviceId: deviceId, key: "isSubscribed", value: isSubscribed)
  }
  
  // MARK: - Private Methods
  
  /// To get notification permission
  /// - Parameter completion: Completion callback
  private static func promptForNotifications(completion: @escaping (Bool) -> Void) {
    Logger.verbose("Start request user notification authorization.")
    
    let options: UNAuthorizationOptions = [.badge, .alert, .sound]
    
    UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
      DispatchQueue.main.async {
        self.permissionState.accepted = granted
        self.permissionState.answeredPrompt = true
        completion(granted)
      }
    }
  }
}
