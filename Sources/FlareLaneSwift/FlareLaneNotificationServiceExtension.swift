//
//  FlareLaneNotificationServiceExtension.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 2022/04/11.
//

import UserNotifications

open class FlareLaneNotificationServiceExtension: UNNotificationServiceExtension {
  override open func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    FlareLaneNotificationServiceExtensionHelper.shared.didReceive(request, withContentHandler: contentHandler)
  }

  override open func serviceExtensionTimeWillExpire() {
    FlareLaneNotificationServiceExtensionHelper.shared.serviceExtensionTimeWillExpire()
  }
}
