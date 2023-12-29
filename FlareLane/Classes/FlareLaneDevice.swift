//
//  FlareLaneDevice.swift
//  FlareLane
//
//  Created by MinHyeok Kim on 12/28/23.
//

import Foundation

@objc open class FlareLaneDevice: NSObject {
  // In case of structure, it is difficult to be compatible with Objective-C
  public var id: String
  public var isSubscribed: Bool
  
  public init(id: String, isSubscribed: Bool) {
    self.id = id
    self.isSubscribed = isSubscribed
  }
  
  open override var description: String {
    return "id:\(id)\nisSubscribed:\(isSubscribed)"
  }
}
