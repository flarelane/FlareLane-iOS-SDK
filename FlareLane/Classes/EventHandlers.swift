//
//  EventHandlers.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class EventHandlers {
  static var unhandledNotification: FlareLaneNotification?
  static var notificationClicked: ((FlareLaneNotification) -> Void)? = nil
  static var notificationForegroundReceived: ((FlareLaneNotificationReceivedEvent) -> Void)? = nil
}
