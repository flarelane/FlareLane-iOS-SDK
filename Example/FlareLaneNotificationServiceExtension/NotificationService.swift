//
//  NotificationService.swift
//  FlareLaneNotificationServiceExtension
//
//  Created by MinHyeok Kim on 2022/04/11.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import FlareLane
import OneSignal

class NotificationService: UNNotificationServiceExtension {
  
  var contentHandler: ((UNNotificationContent) -> Void)?
  var receivedRequest: UNNotificationRequest!
  var bestAttemptContent: UNMutableNotificationContent?
  
  override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    if FlareLaneNotificationServiceExtensionHelper.shared.isFlareLaneNotification(request) {
      FlareLaneNotificationServiceExtensionHelper.shared.didReceive(request, withContentHandler: contentHandler)
    } else {
      self.receivedRequest = request
      self.contentHandler = contentHandler
      self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
      
      if let bestAttemptContent = bestAttemptContent {
        OneSignal.didReceiveNotificationExtensionRequest(self.receivedRequest, with: bestAttemptContent, withContentHandler: self.contentHandler)
      }
    }
  }
  
  override func serviceExtensionTimeWillExpire() {
    FlareLaneNotificationServiceExtensionHelper.shared.serviceExtensionTimeWillExpire()
    
    if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
      OneSignal.serviceExtensionTimeWillExpireRequest(self.receivedRequest, with: self.bestAttemptContent)
      contentHandler(bestAttemptContent)
    }
  }
}
