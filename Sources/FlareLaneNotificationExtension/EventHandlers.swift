//
//  EventHandlers.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

public final class EventHandlers {
  
  public static var unhandledNotification: FlareLaneNotification?
  public static var notificationClicked: ((FlareLaneNotification) -> Void)? = nil
  public static var notificationForegroundReceived: ((FlareLaneNotificationReceivedEvent) -> Void)? = nil
  public static var inAppMessageActionHandler: ((FlareLaneInAppMessage, _ actionId: String) -> Void)? = nil
}
