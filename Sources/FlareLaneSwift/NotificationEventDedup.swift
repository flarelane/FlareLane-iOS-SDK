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

  /// Hash set for O(1) `contains` lookup of dedup keys. Kept in sync with [order]
  /// — both structures must be updated together under [lock].
  private static var processedKeys: Set<String> = []

  /// Insertion-ordered list of the same dedup keys. Lets eviction drop the
  /// *oldest* single entry when the cap is reached, instead of wiping the whole
  /// set (which would leave a "thundering herd" window where every previously
  /// seen notification could fire again). Matches the Android FIFO trim policy
  /// in `NotificationEventProcessor.trimToMax`.
  private static var order: [String] = []

  private static var cacheLoaded = false

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

    loadCacheIfNeeded()

    let key = "\(notificationId)#\(eventType)"
    if processedKeys.contains(key) {
      return false
    }

    // Coarse cap matching the Android bound. The cap is across all event types
    // combined, which is fine because each (id, eventType) pair is a distinct key.
    // Evict BEFORE inserting (and only the oldest, not all) so the new key isn't
    // immediately wiped and so the cache doesn't lose its entire dedup window
    // every time the limit is reached.
    while processedKeys.count >= maxSize, let oldest = order.first {
      order.removeFirst()
      processedKeys.remove(oldest)
    }
    processedKeys.insert(key)
    order.append(key)
    persist()
    return true
  }

  /// Lazy hydrate from `Globals.processedEventKeysInUserDefaults` on the first
  /// call. Filters empty tokens defensively in case the stored value was
  /// corrupted (leading / trailing / repeated commas).
  private static func loadCacheIfNeeded() {
    guard !cacheLoaded else { return }
    cacheLoaded = true

    let stored = Globals.processedEventKeysInUserDefaults ?? ""
    guard !stored.isEmpty else { return }

    let tokens = stored.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    processedKeys = Set(tokens)
    order = tokens
  }

  /// Synchronously write the current dedup set back to UserDefaults so a
  /// force-stop right after the call can't lose the state.
  private static func persist() {
    Globals.processedEventKeysInUserDefaults = order.joined(separator: ",")
  }

  /// Clear the dedup cache. Used by tests and `NotificationClickProcessor`'s
  /// existing `clearProcessedNotificationIds` shim for backward compatibility.
  @objc public static func clearForTesting() {
    lock.lock()
    defer { lock.unlock() }
    processedKeys.removeAll()
    order.removeAll()
    cacheLoaded = false
    Globals.processedEventKeysInUserDefaults = nil
  }
}
