//
//  FlareLaneNotificationReceivedEvent.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 12/18/23.
//

import Foundation

@objc open class FlareLaneNotificationReceivedEvent: NSObject {
  public var notification: FlareLaneNotification
  private var completionHandler: (UNNotificationPresentationOptions) -> Void
  
  init(notification: FlareLaneNotification, completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    self.notification = notification
    self.completionHandler = completionHandler
  }
  
  public func display() {
    completionHandler([.alert, .sound])
  }
}
