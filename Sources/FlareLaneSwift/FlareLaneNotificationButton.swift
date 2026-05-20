//
//  FlareLaneNotificationButton.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

@objc open class FlareLaneNotificationButton: NSObject {
  public var label: String
  public var link: String?

  @objc public init(label: String, link: String?) {
    self.label = label
    self.link = link == "" ? nil : link
  }

  open override var description: String {
    return "label:\(label)\nlink:\(String(describing: link))"
  }

  public func toDictionary() -> [String: Optional<Any>] {
    return [
      "label": label,
      "link": link
    ]
  }

  /// Parse buttons from a push payload. Accepts either:
  ///   - JSON-stringified array (Android / FCM-style payloads): `"[{\"label\":...}]"`
  ///   - Native array (APNS payloads that put the value directly under `aps` siblings): `[{"label":...}]`
  /// Malformed entries are skipped individually rather than failing the whole list (matches Android).
  static func parseButtons(from raw: Any?) -> [FlareLaneNotificationButton]? {
    guard let raw = raw else { return nil }

    let array: [[String: Any]]?
    if let stringValue = raw as? String {
      guard stringValue.isEmpty == false, let data = stringValue.data(using: .utf8) else {
        return nil
      }
      do {
        array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      } catch {
        Logger.error("Notification", "failed to parse buttons", ["error": "\(error)"])
        return nil
      }
    } else if let arrayValue = raw as? [[String: Any]] {
      array = arrayValue
    } else {
      return nil
    }

    guard let entries = array else { return nil }

    let buttons: [FlareLaneNotificationButton] = entries.compactMap { obj in
      guard let label = obj["label"] as? String, label.isEmpty == false else {
        return nil
      }
      let link = obj["link"] as? String
      return FlareLaneNotificationButton(label: label, link: link)
    }
    return buttons.isEmpty ? nil : buttons
  }
}
