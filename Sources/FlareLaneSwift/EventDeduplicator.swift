//
//  EventDeduplicator.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Process-lifetime in-memory dedup for SDK-auto events (CLICKED, FOREGROUND_RECEIVED, BACKGROUND_RECEIVED).
/// Keyed by `"<eventType>:<notificationId>"`. When the in-memory cap is reached the entire set is cleared
/// (same shape as the legacy `NotificationClickProcessor.processedNotificationIds`).
final class EventDeduplicator {
  private static let lock = NSLock()
  private static var seen = Set<String>()
  private static let cap = 200

  /// Returns true if (eventType, notificationId) has been observed before in this process.
  /// Otherwise records it and returns false. Caller should early-return on true.
  static func markAndCheckDuplicate(eventType: String, notificationId: String) -> Bool {
    let key = "\(eventType):\(notificationId)"
    lock.lock()
    defer { lock.unlock() }
    if seen.contains(key) {
      return true
    }
    if seen.count >= cap {
      seen.removeAll()
    }
    seen.insert(key)
    return false
  }
}
