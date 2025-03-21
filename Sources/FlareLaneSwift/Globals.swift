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
  static var sdkVersion = "1.7.4"
  static var sdkType: SdkType = .native
  static var sdkPlatform = "ios"
  
  /// App Group Suite Name
  private static var appGroupSuiteName: String {
    "group.\(bundleIdentifier ?? "").flarelane".trimmingCharacters(in: .whitespaces)
  }
  
  /// Shared UserDefaults instance for App Group
  private static var sharedUserDefaults: UserDefaults? {
    UserDefaults(suiteName: appGroupSuiteName)
  }
  
  /// Standard UserDefaults fallback
  private static var standardDefaults: UserDefaults {
    UserDefaults.standard
  }
  
  // MARK: - Keys
  private enum DefaultsKey: String {
    case projectId = "flarelane_projectIdKey"
    case deviceId = "flarelane_deviceIdKey"
    case userId = "flarelane_userIdKey"
    case pushToken = "flarelane_pushTokenKey"
    case isSubscribed = "flarelane_isSubscribedKey"
    case badgeCount = "flarelane_badgeCount"
  }
  
  /// Generalized Dual Storage Getter
  private static func getValue<T>(forKey key: DefaultsKey) -> T? {
    let sharedValue = sharedUserDefaults?.object(forKey: key.rawValue) as? T
    let standardValue = standardDefaults.object(forKey: key.rawValue) as? T
    
    if sharedValue == nil, let standardValue = standardValue {
      sharedUserDefaults?.set(standardValue, forKey: key.rawValue)
      return standardValue
    }
    
    if standardValue == nil, let sharedValue = sharedValue {
      standardDefaults.set(sharedValue, forKey: key.rawValue)
    }
    
    return sharedValue ?? standardValue
  }
  
  /// Generalized Dual Storage Setter
  private static func setValue<T>(_ value: T?, forKey key: DefaultsKey) {
    sharedUserDefaults?.set(value, forKey: key.rawValue)
    standardDefaults.set(value, forKey: key.rawValue)
  }
  
  /// projectId
  static var projectIdInUserDefaults: String? {
    get { getValue(forKey: .projectId) }
    set { setValue(newValue, forKey: .projectId) }
  }
  
  /// deviceId
  static var deviceIdInUserDefaults: String? {
    get { getValue(forKey: .deviceId) }
    set { setValue(newValue, forKey: .deviceId) }
  }
  
  /// userId
  static var userIdInUserDefaults: String? {
    get { getValue(forKey: .userId) }
    set { setValue(newValue, forKey: .userId) }
  }
  
  /// pushToken
  static var pushTokenInUserDefaults: String? {
    get { getValue(forKey: .pushToken) }
    set { setValue(newValue, forKey: .pushToken) }
  }
  
  /// isSubscribed
  static var isSubscribedInUserDefaults: Bool? {
    get { getValue(forKey: .isSubscribed) }
    set { setValue(newValue, forKey: .isSubscribed) }
  }
  
  /// badgeCount
  static var badgeCountUserDefaults: Int? {
    get { getValue(forKey: .badgeCount) }
    set { setValue(newValue, forKey: .badgeCount) }
  }
  
  static var bundleIdentifier: String? {
    var bundle = Bundle.main
    
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
