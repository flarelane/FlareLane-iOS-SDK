//
//  EventService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class EventService {
  /// Processed when notification is clicked (sends clicked event only)
  /// - Parameter notification: Received notification
  static func createClicked(notification: FlareLaneNotification) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    
    // If the OS reported a button-slot tap, attach button info. Gate is the index (the
    // "was a button clicked" question), so out-of-range / stale-category cases still send
    // isButton=true plus the index; the button label/url are filled in best-effort via
    // the resolved button object. Body-only clicks leave `data` nil — preserves the
    // pre-buttons payload shape.
    var data: [String: Any]? = nil
    if let idx = notification.clickedButtonIndex {
      var d: [String: Any] = [
        "isButton": true,
        "buttonIndex": idx
      ]
      if let button = notification.clickedButton {
        d["buttonLabel"] = button.label
      }
      if let url = notification.clickedUrl, url.isEmpty == false {
        d["url"] = url
      }
      data = d
    }

    API.shared.sendEvent(
      deviceId: deviceId,
      type: "CLICKED",
      notificationId: notification.id,
      data: data
    ) { error in
      if error != nil {
        Logger.error("Failed send event request.")
        return
      }

      Logger.verbose("Succeed send event request.")
    }
  }
  
  /// Processed when notification background received
  /// - Parameter notificationId: ID of received notification
  static func createBackgroundReceived(notificationId: String) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    
    Logger.verbose("Send BACKGROUND_RECEIVED event")
    
    API.shared.sendEvent(
      deviceId: deviceId,
      type: "BACKGROUND_RECEIVED",
      notificationId: notificationId
    ) { error in
      if error != nil {
        Logger.error("Failed send event request.")
        return
      }
      
      Logger.verbose("Succeed send event request.")
    }
  }
  
  /// Processed when notification foreground received
  /// - Parameter notificationId: ID of received notification
  static func createForegroundReceived(notificationId: String) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    
    Logger.verbose("Send FOREGROUND_RECEIVED event")
    
    API.shared.sendEvent(
      deviceId: deviceId,
      type: "FOREGROUND_RECEIVED",
      notificationId: notificationId
    ) { error in
      if error != nil {
        Logger.error("Failed send event request.")
        return
      }
      
      Logger.verbose("Succeed send event request.")
    }
  }
  
  /// Track device event
  /// - Parameters:
  ///   - type: event type
  ///   - data: event data
  static func trackEvent(type: String, data: [String: Any]?) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    API.shared.trackEvent(deviceId: deviceId, type: type, data: data) { (error) in
      if error != nil {
        Logger.error("Failed send event request. \(type)")
        return
      }
      
      Logger.verbose("Succeed send event request. \(type)")
    }
  }
  

  

}
