//
//  NotificationEventDedup.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Extension-safe dedup helper for push notification lifecycle events.
///
/// Lives in its own file (no UIKit / no `@available(iOSApplicationExtension, unavailable)`)
/// because the NotificationServiceExtension code path needs to gate
/// `BACKGROUND_RECEIVED` events from inside an app extension, where
/// `NotificationClickProcessor` (UIKit-dependent for deep-link handling)
/// cannot be referenced.
///
/// Dedup key is `<notificationId>#<eventType>` — same notification id remains
/// independent across CLICKED / FOREGROUND_RECEIVED / BACKGROUND_RECEIVED so a
/// legitimate "received then clicked" still produces two events.
///
/// Storage is hybrid:
///   - In-memory `Set<String>` (with `[String]` for FIFO order) for hot-path
///     `contains` lookup, capped at `maxSize` entries.
///   - Persistent via `Globals.processedEventKeysInUserDefaults` (dual app-group +
///     standard UserDefaults). The dedup decision survives process restart and is
///     shared between the main app and the NotificationServiceExtension — without
///     persistence, a force-stop right after click or an NSE relaunch could let
///     a duplicate event reach the backend.
///
/// Matches the Android `NotificationEventProcessor` policy (FIFO eviction at
/// `MAX_SIZE = 1000`, persistent write on every accept).
@objc public class NotificationEventDedup: NSObject {

  /// Insertion-ordered list of dedup keys. Rebuilt from UserDefaults on every
  /// `shouldProcess` call (see `reloadCache`) so cross-process writes
  /// (main app ↔ NSE) are always visible. `contains` lookup is O(n) but
  /// `maxSize` caps the array at 1000 — negligible compared to the UserDefaults
  /// I/O that already runs each call.
  private static var keys: [String] = []

  private static let maxSize = 1000
  private static let lock = NSLock()

  /// Returns `true` the first time `(notificationId, eventType)` is observed,
  /// `false` for every subsequent call within the retention window. Safe to call
  /// from any thread and from app-extension targets.
  ///
  /// - Parameters:
  ///   - notificationId: FlareLane notification id (server-issued UUID).
  ///   - eventType: One of the `EventType`-style raw values — `CLICKED`,
  ///                `FOREGROUND_RECEIVED`, `BACKGROUND_RECEIVED`.
  @objc public static func shouldProcess(notificationId: String, eventType: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    reloadCache()

    let key = "\(notificationId)#\(eventType)"
    if keys.contains(key) {
      return false
    }

    // Evict the oldest single entry before inserting so the new key survives and
    // the cache doesn't lose its entire dedup window when the cap is reached.
    while keys.count >= maxSize {
      keys.removeFirst()
    }
    keys.append(key)
    persist()
    return true
  }

  /// Refresh in-memory state from shared UserDefaults on every access so writes
  /// from the NotificationServiceExtension (separate process) are observed by
  /// the main app and vice versa. Filters empty tokens defensively in case the
  /// stored value was corrupted (leading / trailing / repeated commas).
  private static func reloadCache() {
    let stored = Globals.processedEventKeysInUserDefaults ?? ""
    guard !stored.isEmpty else {
      keys = []
      return
    }
    keys = stored.split(separator: ",").map(String.init).filter { !$0.isEmpty }
  }

  /// Synchronously write the current dedup set back to UserDefaults so a
  /// force-stop right after the call can't lose the state.
  private static func persist() {
    Globals.processedEventKeysInUserDefaults = keys.joined(separator: ",")
  }

  /// Clear the dedup cache. Used by tests and `NotificationClickProcessor`'s
  /// existing `clearProcessedNotificationIds` shim for backward compatibility.
  @objc public static func clearForTesting() {
    lock.lock()
    defer { lock.unlock() }
    keys.removeAll()
    Globals.processedEventKeysInUserDefaults = nil
  }
}
