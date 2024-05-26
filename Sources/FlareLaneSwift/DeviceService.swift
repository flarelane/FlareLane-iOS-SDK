//
//  DeviceService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

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
      if error != nil {
        Logger.error("Failed create device request.")
        return
      }

      Globals.deviceIdInUserDefaults = deviceId
      Globals.projectIdInUserDefaults = projectId

      Logger.verbose("Succeed create device request.")
      completion()
    }
  }

  /// Update device information to the latest
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  static func activate(deviceId: String, completion: @escaping (() -> Void) = {}) {
    Logger.verbose("Start update device request.")

    var body = self.getSystemInfo()
    // Save recent activations of the device
    body["lastActiveAt"] = Date().toString()

    API.shared.updateDevice(deviceId: deviceId, body: body) { (device, error) in
      if error != nil {
        Logger.error("Failed update device request.")
        return
      }

      Logger.verbose("Succeed update device request.")
      completion()
    }
  }

  /// Update device data such as key and value pair (e.g. tags, userId ...)
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - key: Data key
  ///   - value: Data value
  static func update(body: [String:Any?], completion: ((FlareLaneDevice)->())? = nil) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("Globals.deviceIdInUserDefaults is nil")
      return
    }
    
    API.shared.updateDevice(deviceId: deviceId, body: body) { (response, error) in
      if error != nil {
        Logger.error("Failed update request. - \(body)")
        return
      }

      if let id = response?["id"] as? String,
         let isSubscribed = response?["isSubscribed"] as? Bool {

        let device = FlareLaneDevice(id: id, isSubscribed: isSubscribed)
        self.saveData(body: response)
        Logger.verbose("Succeed update request. - \(body)")

        completion?(device)
      }
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
