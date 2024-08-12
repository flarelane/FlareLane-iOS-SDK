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
  static private let dispatchGroupForInit = DispatchGroup()
  static private let dispatchQueueForInit = DispatchQueue(label: "com.flarelane.dispatchQueue.init")
  static private let inAppMessageThrottler = Throttler(interval: 5)


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
    dispatchGroupForInit.enter()
    dispatchQueueForInit.async {
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
      
      if (BadgeManager.isBadgeEnabled == true) {
        BadgeManager.setCount(0)
        // When using applicationWillEnterForeground, if scenes are already in use, it will not be called. Use willEnterForegroundNotification.
        NotificationCenter.default.addObserver(self, selector: #selector(badgeForegroundHandler), name:  UIApplication.willEnterForegroundNotification, object: nil)
      }
      
      ColdStartNotificationManager.process()

      if let deviceId = Globals.deviceIdInUserDefaults {
        DeviceService.activate(deviceId: deviceId) {
          dispatchGroupForInit.leave()
          if (requestPermissionOnLaunch) {
            requestPermissionForNotifications()
          }
        }
      } else {
        DeviceService.register(projectId: projectId) {
          dispatchGroupForInit.leave()
          if (requestPermissionOnLaunch) {
            requestPermissionForNotifications()
          }
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
  
  @objc public static func setInAppMessageActionHandler(callback: @escaping (FlareLaneInAppMessage, _ actionId: String) -> Void) {
    EventHandlers.inAppMessageActionHandler = callback
    Logger.verbose("InAppMessageClickedHandler has been registered.")
  }

  /// Set userId of device
  /// - Parameter userId: userId
  @objc public static func setUserId(userId: String?) {
    afterInit { deviceId in
      DeviceService.update(deviceId: deviceId, body: ["userId": userId])
    }
  }

  /// Set tags of device
  /// - Parameter tags: tags
  @objc public static func setTags(tags: [String: Any]) {
    afterInit { deviceId in
      DeviceService.update(deviceId: deviceId, body: ["tags": tags])
    }
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
    afterInit { _ in
      EventService.trackEvent(type: type, data: data)
    }
    
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

  static func hasPermissionForNotifications(completion: @escaping (Bool) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      if settings.authorizationStatus == .notDetermined || settings.authorizationStatus == .denied {
        completion(false)
      } else {
        // For stability, default return true
        completion(true)
      }
    }
  }
  
  @objc public static func displayInApp(group: String) {
    afterInit { _ in
      inAppMessageThrottler.throttle {
        InAppMessageService.shared.showInAppMessageIfNeeded(group: group)
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

  /// Update isSubscribe of device
  /// - Parameter isSubscribed: subscribed or not
  private static func setIsSubscribed(isSubscribed: Bool, completion: ((Bool) -> Void)? = nil) {
    afterInit { deviceId in
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
  
  private static func afterInit(completion: @escaping (_ deviceId: String) -> Void) {
    dispatchQueueForInit.async {
      dispatchGroupForInit.wait()
      guard let deviceId = Globals.deviceIdInUserDefaults else {
        Logger.error("no deviceID")
        return
      }
      
      completion(deviceId)
    }
  }
  
  @objc private static func badgeForegroundHandler() {
    BadgeManager.setCount(0)
  }
}
