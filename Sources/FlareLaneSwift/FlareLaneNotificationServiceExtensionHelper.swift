//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
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
    
    if let bestAttemptContent = bestAttemptContent {
      guard let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content),
            let imageUrl = flarelaneNotification.imageUrl,
            let attachmentUrl = URL(string: imageUrl) else {
        contentHandler(bestAttemptContent)
        return
      }
      
      let task = URLSession.shared.downloadTask(with: attachmentUrl) { (downloadedUrl, response, error) in
        if let _ = error {
          contentHandler(bestAttemptContent)
          return
        }
        
        if let downloadedUrl = downloadedUrl, let attachment = try? UNNotificationAttachment(identifier: "flarelane_notification_attachment", url: downloadedUrl, options: [UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG]) {
          bestAttemptContent.attachments = [attachment]
        }
        
        contentHandler(bestAttemptContent)
      }
      
      task.resume()
    }
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
