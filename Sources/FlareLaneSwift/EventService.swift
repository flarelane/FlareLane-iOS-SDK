//
//  EventService.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class EventService {
  // Track processed notification IDs to prevent duplicate clicks across different execution paths
  // This prevents issues in React Native where didReceive may be called before process()
  private static var processedNotificationIds: Set<String> = []
  
  /// Processed when notification is clicked
  /// - Parameter notification: Received notification
  static func createClicked(notification: FlareLaneNotification) {
    // Check for duplicate prevention
    if processedNotificationIds.contains(notification.id) {
      Logger.verbose("Duplicate notification click prevented: \(notification.id)")
      return
    }
    
    // Mark as processed
    processedNotificationIds.insert(notification.id)
    
    // Clean up old entries to prevent memory leaks (keep only last 1000 entries)
    if processedNotificationIds.count > 1000 {
      processedNotificationIds.removeAll()
    }
    
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
  
  /// Clear processed notification tracking cache (useful for testing)
  static func clearProcessedNotifications() {
    processedNotificationIds.removeAll()
    Logger.verbose("Notification tracking cache cleared")
  }
}
