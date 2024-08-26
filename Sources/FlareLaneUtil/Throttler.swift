//
//  Throttler.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

public class Throttler {
  private var lastActionTime: Date = .distantPast
  private let interval: TimeInterval
  
  public init(interval: TimeInterval) {
    self.interval = interval
  }
  
  public func throttle(action: @escaping () -> Void) {
    let now = Date()
    let distance = now.timeIntervalSince(self.lastActionTime)
    
    guard distance > self.interval else { return }
    self.lastActionTime = now
    
    action()
  }
}
