//
//  FlareLane.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
@objc open class FlareLane: NSObject {
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
  ///   - requestPermissionOnLaunch: Request permission for notifications on launch
  @objc public static func initWithLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?, projectId: String, requestPermissionOnLaunch: Bool = true) {
    Logger.verbose("Initialize FlareLane")
    
    
    if (Globals.projectIdInUserDefaults != projectId) {
      // If the previous projectId and the current projectId are not the same, set deviceId to nil for device creation
      Globals.deviceIdInUserDefaults = nil
      Globals.isSubscribedInUserDefaults = nil
    }
    
    // Set projectId before device is registered
    Globals.projectId = projectId
    
    
    ColdStartNotificationManager.setColdStartNotification(launchOptions: launchOptions)
    
    let swizzlingEnabled = Bundle.main.object(forInfoDictionaryKey: swizzlingEnabledKey) as? Bool
    Logger.verbose("FlareLaneSwizzlingEnabled: \(String(describing: swizzlingEnabled))")
    if swizzlingEnabled != false {
      UNUserNotificationCenter.current().delegate = FlareLaneNotificationCenter.shared
      appDelegate.swizzle()
    }
    
    ColdStartNotificationManager.process()
    
    if let deviceId = Globals.deviceIdInUserDefaults {
      DeviceService.activate(deviceId: deviceId) {
        if (requestPermissionOnLaunch) {
          requestPermissionForNotifications()
        }
      }
    } else {
      DeviceService.register(projectId: projectId) {
        if (requestPermissionOnLaunch) {
          requestPermissionForNotifications()
        }
      }
    }
  }
  
  /// Set the handler when notification is clicked
  /// - Parameter callback: Handler callback
  @objc public static func setNotificationClickedHandler(callback: @escaping (FlareLaneNotification) -> Void) {
    EventHandlers.notificationClicked = callback
    Logger.verbose("NotificationClickedHandler has been registered.")
    
    if let unhandledNotification = EventHandlers.unhandledNotification {
      Logger.verbose("found unhandledNotification and execute handler")
      // If the notification is clicked before the handler is set, execute the callback once with unhandledNotification and set unhandledNotification to nil.
      callback(unhandledNotification)
      EventHandlers.unhandledNotification = nil
    }
  }
  
  /// Set the handler when notification foreground received
  /// - Parameter callback: Handler callback
  @objc public static func setNotificationForegroundReceivedHandler(callback: @escaping (FlareLaneNotificationReceivedEvent) -> Void) {
    EventHandlers.notificationForegroundReceived = callback
    Logger.verbose("NotificationForegroundReceivedHandler has been registered.")
  }
  
  /// Set userId of device
  /// - Parameter userId: userId
  @objc public static func setUserId(userId: String?) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    let body = ["userId": userId]
    
    DeviceService.update(deviceId: deviceId, body: body)
  }
  
  /// Get tags of device
  ///  - Parameters:
  ///    - completion: Completion callback
  @objc public static func getTags(completion: @escaping ([String: Any]?) -> Void) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.getTags(deviceId: deviceId) { tags in
      DispatchQueue.main.async {
        completion(tags)
      }
    }
  }
  
  /// Set tags of device
  /// - Parameter tags: tags
  @objc public static func setTags(tags: [String: Any]) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    let body = ["tags": tags]
    
    DeviceService.update(deviceId: deviceId, body: body)
  }
  
  /// Delete tags of device
  /// - Parameter keys: Keys to delete
  @objc public static func deleteTags(keys: [String]) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    DeviceService.deleteTags(deviceId: deviceId, keys: keys)
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
  
  /// Request a permission and subscribe for notifications
  @objc public static func isSubscribed(completion: @escaping (Bool) -> Void) {    
    self.hasPermissionForNotifications() { hasPermission in
      DispatchQueue.main.async {
        if hasPermission == true, Globals.isSubscribedInUserDefaults == true {
          completion(true)
        } else {
          // For stability, default return true
          completion(false)
        }
      }
    }
  }
  
  /// Request a permission and subscribe for notifications
  @objc public static func subscribe(fallbackToSettings: Bool = true, completion: ((Bool) -> Void)? = nil) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      if settings.authorizationStatus == .notDetermined {
        self.requestPermissionForNotifications(completion: completion)
      } else if settings.authorizationStatus == .denied {
        if fallbackToSettings {
          DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
              if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
              }
            } else if #available(iOS 15.4, *) {
              if let url = URL(string: UIApplicationOpenNotificationSettingsURLString) {
                UIApplication.shared.open(url)
              }
            } else {
              if let url = URL(string: "App-Prefs:root=NOTIFICATIONS_ID") {
                UIApplication.shared.open(url)
              }
            }
          }
        }
      } else {
        // Synchronize as much as possible to prevent cases where the token is absent in the DB
        self.requestPermissionForNotifications()
        self.setIsSubscribed(isSubscribed: true) { isSubscribed in
          DispatchQueue.main.async {
            completion?(isSubscribed)
          }
        }
      }
    }
  }
  
  /// Unsubscribe for notifications
  @objc public static func unsubscribe(completion: ((Bool) -> Void)? = nil) {
    self.setIsSubscribed(isSubscribed: false) { isSubscribed in
      DispatchQueue.main.async {
        completion?(isSubscribed)
      }
    }
  }
  
  // MARK: Private Methods
  
  private static func requestPermissionForNotifications(completion: ((Bool) -> Void)? = nil) {
    let options: UNAuthorizationOptions = [.badge, .alert, .sound]
    
    UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
          completion?(true)
        } else {
          completion?(false)
        }
      }
    }
  }
  
  private static func hasPermissionForNotifications(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      if settings.authorizationStatus == .notDetermined || settings.authorizationStatus == .denied {
        completion(false)
      } else {
        // For stability, default return true
        completion(true)
      }
    }
  }
  
  /// Update isSubscribe of device
  /// - Parameter isSubscribed: subscribed or not
  private static func setIsSubscribed(isSubscribed: Bool, completion: ((Bool) -> Void)? = nil) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    var body: [String: Any?] = [
      "isSubscribed": isSubscribed
    ]
    
    if isSubscribed == true {
      body["pushToken"] = Globals.pushTokenInUserDefaults
    }
    
    DeviceService.update(deviceId: deviceId, body: body) { device in
      DispatchQueue.main.sync {
        completion?(device.isSubscribed)
      }
    }
  }
}
