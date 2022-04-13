//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 2022/04/11.
//

import UserNotifications
import MobileCoreServices

@objc public class FlareLaneExtensionHelper: NSObject {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  
  @objc public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
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
    if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
      contentHandler(bestAttemptContent)
    }
  }
}
