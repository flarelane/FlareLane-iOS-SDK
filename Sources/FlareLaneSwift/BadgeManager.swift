//
//  BadgeManager.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation
import UserNotifications

class BadgeManager {
  static private let badgeEnabledKey = "FlareLaneBadgeEnabled"
  
  static func setCount(_ count: Int) {
    if (isBadgeEnabled == false) {
      return
    }
    
    let _count = count < 0 ? 0 : count
    
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(_count)
    }
    
    Globals.badgeCountUserDefaults = _count
  }
  
  static func getCount() -> Int {
    if let count = Globals.badgeCountUserDefaults {
      return count
    }
    return 0
  }
  
  static var isBadgeEnabled: Bool {
    get {
      var bundle: Bundle = Bundle.main
      
      // If it is an extension, use the value of the parent bundle.
      if bundle.bundleURL.pathExtension == "appex" {
        let parentBundleURL = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if let parentBundle = Bundle(url: parentBundleURL) {
          bundle = parentBundle
        }
      }
      
      if let isEnabled = bundle.object(forInfoDictionaryKey: badgeEnabledKey) as? Bool {
        return isEnabled
      }
      
      return true
    }
  }
}
