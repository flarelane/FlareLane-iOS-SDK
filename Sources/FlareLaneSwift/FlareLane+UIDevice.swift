//
//  FlareLane+UIDevice.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UIKit

extension UIDevice {
  static var modelName: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let machine = systemInfo.machine
    let mirror = Mirror(reflecting: machine)
    
    var identifier = ""
    
    for child in mirror.children {
      if let value = child.value as? Int8, value != 0 {
        identifier += String(UnicodeScalar(UInt8(value)))
      }
    }
    return identifier
  }
}
