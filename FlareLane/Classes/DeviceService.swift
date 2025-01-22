//
//  DeviceService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

@available(iOSApplicationExtension, unavailable)
final class DeviceService {
  /// Get system infomation from device
  static func getSystemInfo() -> [String: Any?] {
    // Select the preferred language to avoid errors when the device language and languageCode are different
    let languageCode = Locale.preferredLanguages.count > 0 ? Locale(identifier: Locale.preferredLanguages.first!).languageCode : nil
    
    return [
      "platform": Globals.sdkPlatform,
      "deviceModel":  UIDevice.modelName,
      "osVersion":  UIDevice.current.systemVersion,
      "sdkVersion": Globals.sdkVersion,
      "languageCode": languageCode,
      "countryCode": Locale.current.regionCode,
      "timeZone": TimeZone.current.identifier,
      "apsEnvironment": ApsEnvironment.getEnvironmentString(),
      "bundleId": Bundle.main.bundleIdentifier,
      "sdkType": Globals.sdkType.rawValue
    ]
  }
  
  /// Register device information to FlareLane
  /// - Parameters:
  ///   - projectId: FlareLane projectId
  ///   - pushToken: PushToken from Swizzled delegate
  static func register(projectId: String, completion: @escaping (() -> Void) = {}) {
    Logger.verbose("Start create device request.")
    
    let body = self.getSystemInfo()
    
    API.shared.createDevice(body: body) { (deviceId, error) in
      if let error = error {
        Logger.error("Failed create device request. error: \(error.localizedDescription)")
      } else if let deviceId = deviceId {
        Globals.deviceIdInUserDefaults = deviceId
        Globals.projectIdInUserDefaults = projectId
        Logger.verbose("Succeed create device request.")
      } else {
        Logger.error("createDevice returned no error but deviceId is nil.")
      }
      
      completion()
    }
  }
  
  
  /// Update device information to the latest
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  static func activate(deviceId: String, completion: @escaping (() -> Void) = {}) {
    Logger.verbose("Start update device request.")
    
    FlareLane.hasPermissionForNotifications { hasPermission in
      var body = self.getSystemInfo()
      // Save recent activations of the device
      body["lastActiveAt"] = Date().toString()
      body["notificationPermission"] = hasPermission
      
      API.shared.updateDevice(deviceId: deviceId, body: body) { (device, error) in
        if let error = error {
          Logger.error("Failed update device request. error: \(error.localizedDescription)")
        } else {
          Logger.verbose("Succeed update device request.")
        }
        
        completion()
      }
    }
  }
  
  /// Update device data such as key and value pair (e.g. tags, userId ...)
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - key: Data key
  ///   - value: Data value
  static func update(body: [String: Any?],
                     completion: ((FlareLaneDevice?) -> Void)? = nil) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("Globals.deviceIdInUserDefaults is nil")
      completion?(nil)
      return
    }
    
    API.shared.updateDevice(deviceId: deviceId, body: body) { response, error in
      var device: FlareLaneDevice? = nil
      
      if let error = error {
        Logger.error("Failed update request. - \(body), error: \(error)")
      } else if
        let response = response,
        let id = response["id"] as? String,
        let isSubscribed = response["isSubscribed"] as? Bool {
        
        device = FlareLaneDevice(id: id, isSubscribed: isSubscribed)
        self.saveData(body: response)
        Logger.verbose("Succeed update request. - \(body)")
      } else {
        Logger.error("Unexpected response or missing data. - \(body)")
      }
      
      completion?(device)
    }
  }
  
  // Save data to the local storage.
  private static func saveData(body: [String: Any?]?) {
    if let userIdValue = body?["userId"] {
      if let valid = userIdValue as? String  {
        Globals.userIdInUserDefaults = valid
      } else {
        Globals.userIdInUserDefaults = nil
      }
    }
    
    if let isSubscribedValue = body?["isSubscribed"] {
      if let valid = isSubscribedValue as? Bool  {
        Globals.isSubscribedInUserDefaults = valid
      } else {
        Globals.isSubscribedInUserDefaults = nil
      }
    }
  }
}
