//
//  FlareLaneInAppMessageClickedEvent.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

@objc open class FlareLaneInAppMessage: NSObject {
  
  open var id: String
  
  open var htmlString: String
  
  public init(id: String) {
    self.id = id
    self.htmlString = .init()
    super.init()
  }
  
  public init(id: String, htmlString: String) {
    self.id = id
    self.htmlString = htmlString
  }
  
  open override var description: String {
    return "id:\(id)"
  }
}
