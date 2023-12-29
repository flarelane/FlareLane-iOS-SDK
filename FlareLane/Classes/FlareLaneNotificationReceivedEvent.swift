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
  
  @objc public func display() {
    completionHandler([.alert, .sound])
    Logger.verbose("notification received: \(self.notification)")
    
    // TODO: How to know am i background?
    EventService.createForegroundReceived(notificationId: self.notification.id)
  }
}
