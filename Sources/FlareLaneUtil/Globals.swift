//
//  Globals.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

public enum SdkType: String {
  case native
  case reactnative
  case flutter
}

final public class Globals {
  public static var sdkVersion = "1.7.1"
  public static var sdkType: SdkType = .native
  public static var sdkPlatform = "ios"

  /// projectId before initialization succeeds
  public static var projectId: String? = nil

  /// Save projectId in local storage
  private static var projectIdKey = "flarelane_projectIdKey"
  public static var projectIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: projectIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: projectIdKey)
    }
  }

  /// Save deviceId in local storage
  private static var deviceIdKey = "flarelane_deviceIdKey"
  public static var deviceIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: deviceIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: deviceIdKey)
    }
  }

  /// Save userId in local storage
  private static var userIdKey = "flarelane_userIdKey"
  public static var userIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: userIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: userIdKey)
    }
  }

  /// Save pushToken in local storage
  private static var pushTokenKey = "flarelane_pushTokenKey"
  public static var pushTokenInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: pushTokenKey)
    }

    get {
      UserDefaults.standard.string(forKey: pushTokenKey)
    }
  }

  /// Save isSubscribed in local storage
  private static var isSubscribedKey = "flarelane_isSubscribedKey"
  public static var isSubscribedInUserDefaults: Bool? {
    set {
      UserDefaults.standard.set(newValue, forKey: isSubscribedKey)
    }

    get {
      UserDefaults.standard.bool(forKey: isSubscribedKey)
    }
  }

  private static var badgeCount = "flarelane_badgeCount"
  public static var badgeCountUserDefaults: Int? {
    set {
      if let userDefaults = shardUserDefaults {
        userDefaults.set(newValue, forKey: badgeCount)
      }
    }

    get {
      if let userDefaults = shardUserDefaults {
        return userDefaults.integer(forKey: badgeCount)
      } else {
        return nil
      }
    }
  }

  public static var shardUserDefaults: UserDefaults? {
    get {
      UserDefaults(suiteName: appGroupName)
    }
  }

  public static var appGroupName: String {
    let appGroupName = "group.\(bundleIdentifier ?? "").flarelane"
    return appGroupName.trimmingCharacters(in: .whitespaces)
  }

  public static var bundleIdentifier: String? {
    var bundle = Bundle.main

    // If it is an extension, use the value of the parent bundle.
    if bundle.bundleURL.pathExtension == "appex" {
      bundle = Bundle(url: bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent())!
    }

    return bundle.bundleIdentifier
  }

  /// Current logLevel
  public static var logLevel: LogLevel = .verbose

  /// Swizzled or not
  public static var swizzled: Bool = false
}
