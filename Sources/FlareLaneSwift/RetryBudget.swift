//
//  RetryBudget.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Caps how many requests may be waiting out a backoff at the same time.
///
/// Retries multiply outstanding work: during a long outage each failing call would park two more
/// attempts, so the pile grows several times faster than the calls arrive. Past the limit a request
/// is failed straight away instead of being parked.
///
/// This bounds retries only. A host app that keeps calling while offline still queues its original
/// requests — bounding those means holding events somewhere durable, which this SDK deliberately
/// does not do. Mirrors the Android SDK's RetryBudget.
final class RetryBudget {

  private let limit: Int
  private let lock = NSLock()
  private var waiting = 0

  init(limit: Int) {
    self.limit = limit
  }

  /// Takes a slot if one is free.
  ///
  /// - Returns: `true` when a slot was taken, in which case the caller must ``release()`` it once
  ///   the retry starts; `false` when the budget is full and the request should give up now.
  func tryAcquire() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard waiting < limit else {
      return false
    }
    waiting += 1
    return true
  }

  func release() {
    lock.lock()
    defer { lock.unlock() }

    waiting = max(0, waiting - 1)
  }

  /// Visible for tests.
  var waitingCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return waiting
  }
}
