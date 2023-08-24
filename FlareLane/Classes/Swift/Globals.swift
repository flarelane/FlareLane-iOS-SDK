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
  static var sdkVersion = "1.3.2"
  static var sdkType: SdkType = .native

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

  /// Current logLevel
  static var logLevel: LogLevel = .verbose

  /// Swizzled or not
  static var swizzled: Bool = false
}
