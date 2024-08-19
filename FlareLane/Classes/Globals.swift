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

final class Globals {
  static var sdkVersion = "1.7.1"
  static var sdkType: SdkType = .native
  static var sdkPlatform = "ios"

  /// projectId before initialization succeeds
  static var projectId: String? = nil

  /// Save projectId in local storage
  private static var projectIdKey = "flarelane_projectIdKey"
  static var projectIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: projectIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: projectIdKey)
    }
  }

  /// Save deviceId in local storage
  private static var deviceIdKey = "flarelane_deviceIdKey"
  static var deviceIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: deviceIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: deviceIdKey)
    }
  }

  /// Save userId in local storage
  private static var userIdKey = "flarelane_userIdKey"
  static var userIdInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: userIdKey)
    }

    get {
      UserDefaults.standard.string(forKey: userIdKey)
    }
  }

  /// Save pushToken in local storage
  private static var pushTokenKey = "flarelane_pushTokenKey"
  static var pushTokenInUserDefaults: String? {
    set {
      UserDefaults.standard.set(newValue, forKey: pushTokenKey)
    }

    get {
      UserDefaults.standard.string(forKey: pushTokenKey)
    }
  }

  /// Save isSubscribed in local storage
  private static var isSubscribedKey = "flarelane_isSubscribedKey"
  static var isSubscribedInUserDefaults: Bool? {
    set {
      UserDefaults.standard.set(newValue, forKey: isSubscribedKey)
    }

    get {
      UserDefaults.standard.bool(forKey: isSubscribedKey)
    }
  }

  private static var badgeCount = "flarelane_badgeCount"
  static var badgeCountUserDefaults: Int? {
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

  static var shardUserDefaults: UserDefaults? {
    get {
      UserDefaults(suiteName: appGroupName)
    }
  }

  static var appGroupName: String {
    let appGroupName = "group.\(bundleIdentifier ?? "").flarelane"
    return appGroupName.trimmingCharacters(in: .whitespaces)
  }

  static var bundleIdentifier: String? {
    var bundle = Bundle.main

    // If it is an extension, use the value of the parent bundle.
    if bundle.bundleURL.pathExtension == "appex" {
      bundle = Bundle(url: bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent())!
    }

    return bundle.bundleIdentifier
  }

  /// Current logLevel
  static var logLevel: LogLevel = .verbose

  /// Swizzled or not
  static var swizzled: Bool = false
}
