//
//  FlareLaneNotificationCommunication.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Chat-style (communication) notification payload: who the push should appear to be from.
/// Both fields are required — the whole point of the feature is the sender avatar, so a
/// payload without either renders as a normal notification instead of a broken chat bubble.
@objc open class FlareLaneNotificationCommunication: NSObject {
  public var senderName: String
  public var senderImageUrl: String

  @objc public init(senderName: String, senderImageUrl: String) {
    self.senderName = senderName
    self.senderImageUrl = senderImageUrl
  }

  open override var description: String {
    return "senderName:\(senderName)\nsenderImageUrl:\(senderImageUrl)"
  }

  /// JSON-serializable representation for the cross-platform bridge.
  public func toDictionary() -> [String: Any] {
    return [
      "senderName": senderName,
      "senderImageUrl": senderImageUrl
    ]
  }

  /// Parse from a push payload. Accepts either:
  ///   - Native dictionary (APNS payloads): `{"senderName": ..., "senderImageUrl": ...}`
  ///   - JSON-stringified object (Android / FCM-style payloads)
  /// Returns nil (never crashes) when either required field is missing or empty, which makes
  /// the caller deliver a normal notification.
  static func parse(from raw: Any?) -> FlareLaneNotificationCommunication? {
    guard let raw = raw else { return nil }

    let object: [String: Any]?
    if let stringValue = raw as? String {
      guard stringValue.isEmpty == false, let data = stringValue.data(using: .utf8) else {
        return nil
      }
      do {
        object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      } catch {
        Logger.error("Failed to parse notification communication.", error: error)
        return nil
      }
    } else if let dictValue = raw as? [String: Any] {
      object = dictValue
    } else {
      return nil
    }

    guard let entry = object,
          let senderName = entry["senderName"] as? String, senderName.isEmpty == false,
          let senderImageUrl = entry["senderImageUrl"] as? String, senderImageUrl.isEmpty == false else {
      return nil
    }

    return FlareLaneNotificationCommunication(senderName: senderName, senderImageUrl: senderImageUrl)
  }
}
