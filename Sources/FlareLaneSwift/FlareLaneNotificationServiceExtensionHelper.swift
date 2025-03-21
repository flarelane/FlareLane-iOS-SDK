//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UserNotifications
import MobileCoreServices

@objc public class FlareLaneNotificationServiceExtensionHelper: NSObject {
  @objc public static let shared = FlareLaneNotificationServiceExtensionHelper()
  
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  
  @objc public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    Logger.verbose("INVOKED")
    
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
    
    if let badgeCount = bestAttemptContent?.badge as? Int {
      BadgeManager.setCount(badgeCount)
    } else {
      BadgeManager.setCount(BadgeManager.getCount() + 1)
    }
    
    guard let bestAttemptContent = bestAttemptContent,
          let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) else {
      contentHandler(self.bestAttemptContent ?? request.content)
      return
    }
    
    // Only Background. Cannot split background~foreground in extension.
    EventService.createBackgroundReceived(notificationId: flarelaneNotification.id)
    
    guard let imageUrl = flarelaneNotification.imageUrl,
          let attachmentUrl = URL(string: imageUrl) else {
      contentHandler(bestAttemptContent)
      return
    }
    
    let task = URLSession.shared.downloadTask(with: attachmentUrl) { downloadedUrl, response, error in
      defer { contentHandler(bestAttemptContent) }
      
      if let downloadedUrl = downloadedUrl,
         let attachment = try? UNNotificationAttachment(identifier: "flarelane_notification_attachment",
                                                        url: downloadedUrl,
                                                        options: [UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG]) {
        bestAttemptContent.attachments = [attachment]
      }
    }
    
    task.resume()
  }
  
  
  @objc public func serviceExtensionTimeWillExpire() {
    Logger.verbose("INVOKED")
    
    if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
  
  @objc public func isFlareLaneNotification(_ request: UNNotificationRequest) -> Bool {
    if let _ = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) {
      return true
    }
    
    return false
  }
}
