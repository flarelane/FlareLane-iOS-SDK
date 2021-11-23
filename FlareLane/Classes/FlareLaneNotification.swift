//
//  FlareLaneNotification.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

@objc public class FlareLaneNotification: NSObject {
  // In case of structure, it is difficult to be compatible with Objective-C
  public var id: String
  public var body: String
  public var title: String?
  public var url: String?
  
  public init(id: String, body: String, title: String?, url: String?) {
    self.id = id;
    self.body = body;
    // To avoid unexpected blank lines in place of titles
    self.title = title == "" ? nil : title;
    self.url = url;
  }
  
  public func toDictionary () -> [String: Optional<String>] {
    let data = ["id": self.id,
                "title": self.title,
                "body": self.body,
                "url": self.url]
    
    return data
  }
  
  static func getFlareLaneNotificationFromUserInfo(userInfo: [AnyHashable: Any]) -> FlareLaneNotification? {
    guard let aps = userInfo["aps"] as? Dictionary<String, Any>,
          let alert = aps["alert"] as? Dictionary<String, Any>,
          let notificationId = userInfo["notificationId"] as? String,
          let body = alert["body"] as? String else {
            Logger.error("Failed to get FlareLaneNotification: Missing required keys")
            return nil
          }
    
    let isFlareLane = userInfo["isFlareLane"] as? Bool
    if (isFlareLane != nil && isFlareLane != true) {
      Logger.error("Not a notification from FlareLane.")
      return nil
    }
    
    let notification = FlareLaneNotification(id: notificationId,
                                             body:body,
                                             title:alert["title"] as? String,
                                             url: userInfo["url"] as? String)
    
    return notification
  }
  
  static func getFlareLaneNotificationFromLaunchOptions (launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> FlareLaneNotification? {
    guard let userInfo = launchOptions?[.remoteNotification] as? Dictionary<String, Any>,
          let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo) else {
            return nil
          }
    
    return notification;
  }
  
  static func getFlareLaneNotificationFromUNNotification(notification: UNNotification) -> FlareLaneNotification? {
    guard let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: notification.request.content.userInfo) else {
      return nil
    }
    
    return flarelaneNotification
  }
  
  static func isFlareLaneNotification (notification: UNNotification) -> Bool {
    if (notification.request.content.userInfo["isFlareLane"] as? Bool == true) {
      return true
    }
    return false
  }
}
