//
//  Throttler.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

class Throttler {
  private var lastActionTime: Date = .distantPast
  private let interval: TimeInterval
  
  init(interval: TimeInterval) {
    self.interval = interval
  }
  
  func throttle(action: @escaping () -> Void) {
    let now = Date()
    let distance = now.timeIntervalSince(self.lastActionTime)
    
    guard distance > self.interval else {
      Logger.verbose("Throttler", "action throttled", ["interval": self.interval, "distance": distance])
      return
    }
    self.lastActionTime = now
    
    action()
  }
}
