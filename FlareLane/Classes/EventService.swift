//
//  EventService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class EventService {
  /// Processed when notification is clicked
  /// - Parameter notification: Received notification
  static func createClicked(notification: FlareLaneNotification) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    
    API.shared.sendEvent(   
      deviceId: deviceId,
      type: "CLICKED",
      notificationId: notification.id
    ) { error in
      if error != nil {
        Logger.error("Failed send event request.")
        return
      }
      
      Logger.verbose("Succeed send event request.")
    }
    
    guard let clickedHandler = EventHandlers.notificationClicked else {
      Logger.verbose("unhandledNotification saved")
      // If notificationClicked handler is nil, the last notification is saved and executed when the handler is registered.
      EventHandlers.unhandledNotification = notification
      return
    }
    
    Logger.verbose("clickedHandler found, execute handler")
    clickedHandler(notification)
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
  static func trackEvent(type: String , data: [String: Any]?) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      return
    }
    
    let userId = Globals.userIdInUserDefaults
    
    let subjectType = userId != nil ? "user": "device"
    let subjectId = userId ?? deviceId
    
    API.shared.trackEvent(subjectType: subjectType, subjectId: subjectId, type: type, data: data) { (error) in
      if error != nil {
        Logger.error("Failed send event request. \(type)")
        return
      }
      
      Logger.verbose("Succeed send event request. \(type)")
    }
  }
}
