//
//  FlareLaneNotificationReceivedEvent.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 12/18/23.
//

import UIKit

@objc open class FlareLaneNotificationReceivedEvent: NSObject {
  @objc public var notification: FlareLaneNotification
  private var application: UIApplication
  private var completionHandler: (UNNotificationPresentationOptions) -> Void
  
  init(_ application: UIApplication, notification: FlareLaneNotification, completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    self.application = application
    self.notification = notification
    self.completionHandler = completionHandler
  }
  
  @objc public func display() {
    Logger.verbose("notification received: \(self.notification)")
    completionHandler([.alert, .sound])
    
    if application.applicationState == .active {
      EventService.createForegroundReceived(notificationId: self.notification.id)
    } else {
      // TODO: Needs EventService.createBackgroundReceived
    }
  }
}
