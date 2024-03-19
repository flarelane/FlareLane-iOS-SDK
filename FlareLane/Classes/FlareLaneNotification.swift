//
//  FlareLaneNotification.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

@objc open class FlareLaneNotification: NSObject {
  // In case of structure, it is difficult to be compatible with Objective-C
  public var id: String
  public var body: String
  public var title: String?
  public var url: String?
  public var imageUrl: String?
  public var data: Dictionary<String, Any>?
  
  public init(id: String, body: String, title: String?, url: String?, imageUrl: String?, data: Dictionary<String, Any>?) {
    self.id = id
    self.body = body
    self.data = data
    // To avoid unexpected blank lines in place of titles
    self.title = title == "" ? nil : title
    self.url = url == "" ? nil : url
    self.imageUrl = imageUrl == "" ? nil : imageUrl
  }
  
  open override var description: String {
    return "id:\(id)\nbody:\(body)\ntitle:\(String(describing: title))\nurl:\(String(describing: url))\nimageUrl:\(String(describing: imageUrl))\ndata:\(String(describing: data))"
  }
  
  static func getFlareLaneNotificationFromUserInfo(userInfo: [AnyHashable: Any]) -> FlareLaneNotification? {
    
    let isFlareLane = userInfo["isFlareLane"] as? Bool
    if (isFlareLane != true) {
      Logger.error("Not a notification from FlareLane.")
      return nil
    }
    
    guard let aps = userInfo["aps"] as? Dictionary<String, Any>,
          let alert = aps["alert"] as? Dictionary<String, Any>,
          let notificationId = userInfo["notificationId"] as? String,
          let body = alert["body"] as? String else {
            Logger.error("Failed to get FlareLaneNotification: Missing required keys")
            return nil
          }
    
    let notification = FlareLaneNotification(id: notificationId,
                                             body:body,
                                             title:alert["title"] as? String,
                                             url: userInfo["url"] as? String,
                                             imageUrl: userInfo["imageUrl"] as? String,
                                             data: userInfo["data"] as? Dictionary<String, Any>
    )
    
    return notification
  }
  
  static func getFlareLaneNotificationFromLaunchOptions (launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> FlareLaneNotification? {
    guard let userInfo = launchOptions?[.remoteNotification] as? Dictionary<String, Any>,
          let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo) else {
            return nil
          }
    
    return notification
  }
  
  public static func getFlareLaneNotificationFromUNNotificationContent(_ notificationContent: UNNotificationContent) -> FlareLaneNotification? {
    guard let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: notificationContent.userInfo) else {
      return nil
    }
    
    return flarelaneNotification
  }
  
  public func toDictionary() -> [String: Optional<Any>] {
    let dict: [String: Optional<Any>] = [
      "id": id,
      "title": title,
      "body": body,
      "url": url,
      "imageUrl": imageUrl,
      "data": data
    ]
    
    return dict
  }
}
