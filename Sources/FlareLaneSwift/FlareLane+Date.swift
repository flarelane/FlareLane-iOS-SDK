//
//  FlareLane+Date.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

extension Date {
  func toString() -> String {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    return dateFormatter.string(from: self as Date)
  }
}
