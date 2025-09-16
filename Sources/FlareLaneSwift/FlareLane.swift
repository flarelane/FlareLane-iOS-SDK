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
  static private let inAppMessageThrottler = Throttler(interval: 0.5)
  static private let taskManager = FlareLaneTaskManager.shared

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
    Globals.projectIdInUserDefaults = projectId


    ColdStartNotificationManager.setColdStartNotification(launchOptions: launchOptions)

    if (BadgeManager.isBadgeEnabled == true) {
      BadgeManager.setCount(0)
      // When using applicationWillEnterForeground, if scenes are already in use, it will not be called. Use willEnterForegroundNotification.
      NotificationCenter.default.addObserver(self, selector: #selector(badgeForegroundHandler), name:  UIApplication.willEnterForegroundNotification, object: nil)
    }

    ColdStartNotificationManager.process()

    if let deviceId = Globals.deviceIdInUserDefaults {
      DeviceService.activate(deviceId: deviceId) {
        if (requestPermissionOnLaunch) {
          self.requestPermissionForNotifications() { _ in
            taskManager.initializeComplete()
          }
        } else {
          taskManager.initializeComplete()
        }
      }
    } else {
      DeviceService.register(projectId: projectId) {
        if (requestPermissionOnLaunch) {
          self.requestPermissionForNotifications() { _ in
            taskManager.initializeComplete()
          }
        } else {
          taskManager.initializeComplete()
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
    taskManager.addTaskAfterInit(taskName: "setUserId") { completionTask in
      DeviceService.update(body: ["userId": userId]) { _ in
        completionTask()
      }
    }
  }

  /// Set tags of device
  /// - Parameter tags: tags
  @objc public static func setTags(tags: [String: Any]) {
    taskManager.addTaskAfterInit(taskName: "setTags") { completionTask in
      DeviceService.update(body: ["tags": tags]) { _ in
        completionTask()
      }
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
    taskManager.addTaskAfterInit(taskName: "trackEvent") { completionTask in
      EventService.trackEvent(type: type, data: data)
      completionTask()
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
    taskManager.addTaskAfterInit(taskName: "subscribe") { completionTask in
      let completeAll: (Bool) -> Void = { result in
        completion?(result)
        completionTask()
      }

      UNUserNotificationCenter.current().getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .notDetermined:
          self.requestPermissionForNotifications { granted in
            completeAll(granted)
          }
        case .denied:
          if fallbackToSettings {
            DispatchQueue.main.async {
              self.openNotificationSettings()
            }
          }
          completeAll(false)
        default:
          if Globals.pushTokenInUserDefaults == nil {
            self.requestPermissionForNotifications { granted in
              completeAll(granted)
            }
          } else {
            self.updateDeviceWithPushToken {
              completeAll(true)
            }
          }
        }
      }
    }
  }



  /// Unsubscribe for notifications
  @objc public static func unsubscribe(completion: ((Bool) -> Void)? = nil) {
    FlareLane.hasPermissionForNotifications { hasPermission in
      taskManager.addTaskAfterInit(taskName: "unsubscribe") { completionTask in
        DeviceService.update(body: [
          "isSubscribed": false,
          "notificationPermission": hasPermission
        ]) { device in
          let isSubscribed = (device?.isSubscribed ?? Globals.isSubscribedInUserDefaults) ?? false

          DispatchQueue.main.async {
            completion?(isSubscribed)
          }
          completionTask()
        }
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

  @objc public static func displayInApp(group: String, data: [String: Any]? = nil) {
    inAppMessageThrottler.throttle {
      taskManager.addTaskAfterInit(taskName: "displayInApp") { completionTask in
        InAppMessageService.shared.showInAppMessageIfNeeded(group: group, data: data)
        completionTask()
      }
    }
  }

  /// Reset device data and clear all cached information
  @objc public static func resetDevice() {
    Logger.verbose("resetDevice: Clearing all cached device data")

    taskManager.addTaskAfterInit(taskName: "resetDevice") { completionTask in
      // Clear all cached device data
      Globals.deviceIdInUserDefaults = nil
      Globals.userIdInUserDefaults = nil
      Globals.isSubscribedInUserDefaults = nil
      Globals.pushTokenInUserDefaults = nil
      Globals.badgeCountUserDefaults = nil
      Globals.projectIdInUserDefaults = nil
      // Reset task queue state
      taskManager.reset()
      Logger.verbose("resetDevice: Device data and task queue cleared successfully")

      completionTask()
    }
  }

  // MARK: Private Methods

  private static func updateDeviceWithPushToken(completion: @escaping () -> Void) {
    FlareLane.hasPermissionForNotifications { hasPermission in
      if let pushToken = Globals.pushTokenInUserDefaults {
        DeviceService.update(body: [
          "isSubscribed": true,
          "pushToken": pushToken,
          "notificationPermission": hasPermission
        ]) { device in
          DispatchQueue.main.async {
            completion()
          }
        }
      } else {
        completion()
      }
    }
  }

  private static func openNotificationSettings() {
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

  @objc private static func badgeForegroundHandler() {
    BadgeManager.setCount(0)
  }
}
