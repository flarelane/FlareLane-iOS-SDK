//
//  EventHandlers.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class EventHandlers {
  static var unhandledNotification: FlareLaneNotification?
  static var notificationConverted: ((FlareLaneNotification) -> Void)? = nil
}
