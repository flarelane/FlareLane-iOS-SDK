//
//  FlareLane.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
@objc open class FlareLane: NSObject {
  static private var permissionState = PermissionState()
  static private var appDelegate = FlareLaneAppDelegate()
  static private let swizzlingEnabledKey = "FlareLaneSwizzlingEnabled"
  
  // MARK: - Public Methods
  
  /// Set level to logging
  /// - Parameter level: LogLevel, Default is verbose
  @objc public static func setLogLevel(level: LogLevel) {
    Logger.verbose("Change log level to \(level)")
    Globals.logLevel = level
  }
  
  /// Set sdk info
  /// - Parameters:
  ///   - sdkType: Platform in which the SDK runs
  ///   - sdkVersion: Version of SDK by Platform
  /// Must called before initWithLaunchOptions
  public static func setSdkInfo(sdkType: SdkType, sdkVersion: String) {
    Logger.verbose("Set sdk info to \(sdkType), \(sdkVersion)")
    Globals.sdkType = sdkType
    Globals.sdkVersion = sdkVersion
  }
  
  /// Initialize FlareLane SDK
  /// - Parameters:
  ///   - projectId: FlareLane projectId
  ///   - launchOptions: AppDelegate didFinishLaunchingWithOptions
  @objc public static func initWithLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?, projectId: String, disableInitialPrompt: Bool = false) {
    Logger.verbose("Initialize FlareLane")
    
    
    if (Globals.projectIdInUserDefaults != projectId) {
      // If the previous projectId and the current projectId are not the same, set deviceId to nil for device creation
      Globals.deviceIdInUserDefaults = nil;
    }
    
    // Set projectId before device is registered
    Globals.projectId = projectId
    
    // Set disableInitialPrompt
    // The parameter was set to Bool = false for @objc compatibility because an optional Bool cannot be used.
    Globals.disableInitialPrompt = disableInitialPrompt;
    
    ColdStartNotificationManager.setColdStartNotification(launchOptions: launchOptions)
    
    let swizzlingEnabled = Bundle.main.object(forInfoDictionaryKey: swizzlingEnabledKey) as? Bool
    Logger.verbose("FlareLaneSwizzlingEnabled: \(String(describing: swizzlingEnabled))")
    if swizzlingEnabled != false {
      UNUserNotificationCenter.current().delegate = FlareLaneNotificationCenter.shared
      appDelegate.swizzle()
    }
    
    ColdStartNotificationManager.process()
    
    
    self.permissionState.initialized = true
    
    if (Globals.disableInitialPrompt) {
      Logger.verbose("Initial prompt has been disabled")
      // if it's the first device registration, initially create the device
      if (Globals.deviceIdInUserDefaults == nil) {
        if (self.permissionState.calledPromptForNotificationsBeforeIntialized) {
          self.promptForNotifications()
          self.permissionState.calledPromptForNotificationsBeforeIntialized = false
        } else {
          DeviceService.register(projectId: projectId, pushToken: nil)
        }
      } else {
        Logger.verbose("Notification allowed. updating device")
        // Update the device only when push notifications are allowed
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          if settings.authorizationStatus == .authorized {
              self.promptForNotifications()
          } else if #available(iOS 12, *), settings.authorizationStatus == .provisional {
              self.promptForNotifications()
          } else if #available(iOS 14, *), settings.authorizationStatus == .ephemeral {
              self.promptForNotifications()
          }
        }
      }
    } else {
      self.promptForNotifications()
    }
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
  
  /// Get tags of device
  ///  - Parameters:
  ///    - completion: Completion callback
  @objc public static func getTags(completion: @escaping ([String: Any]?) -> Void) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.getTags(deviceId: deviceId) { tags in
      completion(tags);
    }
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
  /// - Parameter isSubscribed: subscribed or not
  @objc public static func setIsSubscribed(isSubscribed: Bool) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.update(deviceId: deviceId, key: "isSubscribed", value: isSubscribed)
  }
  
  /// Get id of device
  @objc public static func getDeviceId() -> String? {
    return Globals.deviceIdInUserDefaults
  }
  
  // Track event
  /// - Parameters:
  ///   - type: event type
  ///   - data: event data
  @objc public static func trackEvent(_ type: String, data: [String: Any]? = nil) {
    EventService.trackEvent(type: type, data: data)
  }
  
  /// To get notification permission
  /// - Parameter completion: Completion callback
  @objc public static func promptForNotifications() {
    Logger.verbose("Start request user notification authorization.")
    
    if (!self.permissionState.initialized) {
      Logger.verbose("promptForNotifications: Called before Initialize. will execute after Initialize")
      self.permissionState.calledPromptForNotificationsBeforeIntialized = true;
      return;
    }
    
    let options: UNAuthorizationOptions = [.badge, .alert, .sound]
    
    UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
      DispatchQueue.main.async {
        self.permissionState.accepted = granted
        self.permissionState.answeredPrompt = true
        
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
  }
}
