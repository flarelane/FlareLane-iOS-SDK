//
//  FlareLaneInAppMessageClickedEvent.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

@objc open class FlareLaneInAppMessageClickedEvent: NSObject {
  public var messageId: String
  public var actionId: String
  
  public init(messageId: String, actionId: String) {
    self.messageId = messageId
    self.actionId = actionId
  }
  
  open override var description: String {
    return "messageId:\(messageId)\nactionId:\(actionId)"
  }
}
