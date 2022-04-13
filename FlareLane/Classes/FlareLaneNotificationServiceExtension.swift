//
//  FlareLaneNotificationServiceExtension.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 2022/04/11.
//

import UserNotifications

open class FlareLaneNotificationServiceExtension: UNNotificationServiceExtension {
  let extensionHelper = FlareLaneExtensionHelper()

  override open func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    extensionHelper.didReceive(request, withContentHandler: contentHandler)
  }

  override open func serviceExtensionTimeWillExpire() {
    extensionHelper.serviceExtensionTimeWillExpire()
  }
}
