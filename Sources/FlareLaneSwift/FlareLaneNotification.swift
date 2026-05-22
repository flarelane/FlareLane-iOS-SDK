//
//  FlareLaneNotification.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications
import UIKit

@objc open class FlareLaneNotification: NSObject {
  // In case of structure, it is difficult to be compatible with Objective-C
  public var id: String
  public var body: String
  public var title: String?
  public var url: String?
  public var imageUrl: String?
  public var data: Dictionary<String, Any>?
  public var buttons: [FlareLaneNotificationButton]?
  public var clickedButtonIndex: Int?

  public init(id: String, body: String, title: String?, url: String?, imageUrl: String?, data: Dictionary<String, Any>?, buttons: [FlareLaneNotificationButton]? = nil, clickedButtonIndex: Int? = nil) {
    self.id = id
    self.body = body
    self.data = data
    // To avoid unexpected blank lines in place of titles
    self.title = title == "" ? nil : title
    self.url = url == "" ? nil : url
    self.imageUrl = imageUrl == "" ? nil : imageUrl
    self.buttons = buttons
    self.clickedButtonIndex = clickedButtonIndex
  }

  open override var description: String {
    return "id:\(id)\nbody:\(body)\ntitle:\(String(describing: title))\nurl:\(String(describing: url))\nimageUrl:\(String(describing: imageUrl))\ndata:\(String(describing: data))\nbuttons:\(String(describing: buttons))\nclickedButtonIndex:\(String(describing: clickedButtonIndex))"
  }

  /// The button the user actually tapped, or `nil` for a body click / out-of-range index.
  /// Prefer this object accessor over reaching into `buttons[clickedButtonIndex]` yourself.
  public var clickedButton: FlareLaneNotificationButton? {
    guard let idx = clickedButtonIndex,
          let buttons = buttons,
          idx >= 0,
          idx < buttons.count else {
      return nil
    }
    return buttons[idx]
  }

  /// URL associated with the click — picks one of two sources based on **what was clicked**:
  ///
  ///   - **Button click** (`clickedButtonIndex != nil`): the tapped button's link, or `nil`
  ///     when the button has no link (including out-of-range / missing button data).
  ///   - **Body click** (`clickedButtonIndex == nil`): the notification body's `url`, or
  ///     `nil` when none is set.
  ///
  /// ⚠️ A button click with no link returns `nil`, **not** the body's `url`. Body and
  /// button URLs are conceptually distinct destinations — the click target determines which
  /// source is valid, and falling through would silently navigate users to the body URL
  /// when they tapped a button that intentionally has none.
  public var clickedUrl: String? {
    return clickedButtonIndex != nil ? clickedButton?.link : url
  }

  public func withClickedButtonIndex(_ idx: Int) -> FlareLaneNotification {
    return FlareLaneNotification(
      id: id,
      body: body,
      title: title,
      url: url,
      imageUrl: imageUrl,
      data: data,
      buttons: buttons,
      clickedButtonIndex: idx
    )
  }

  static func getFlareLaneNotificationFromUserInfo(userInfo: [AnyHashable: Any]) -> FlareLaneNotification? {

    let isFlareLane = userInfo["isFlareLane"] as? Bool
    if (isFlareLane != true) {
      Logger.error("Not a notification from FlareLane.")
      return nil
    }

    guard let aps = userInfo["aps"] as? Dictionary<String, Any>,
          let alert = aps["alert"] as? Dictionary<String, Any>,
          let notificationId = userInfo["notificationId"] as? String,
          let body = alert["body"] as? String else {
            Logger.error("Failed to get FlareLaneNotification: Missing required keys")
            return nil
          }

    let buttons = FlareLaneNotificationButton.parseButtons(from: userInfo["buttons"])

    let notification = FlareLaneNotification(id: notificationId,
                                             body:body,
                                             title:alert["title"] as? String,
                                             url: userInfo["url"] as? String,
                                             imageUrl: userInfo["imageUrl"] as? String,
                                             data: userInfo["data"] as? Dictionary<String, Any>,
                                             buttons: buttons
    )

    return notification
  }

  static func getFlareLaneNotificationFromLaunchOptions (launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> FlareLaneNotification? {
    guard let userInfo = launchOptions?[.remoteNotification] as? Dictionary<String, Any>,
          let notification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: userInfo) else {
            return nil
          }

    return notification
  }

  public static func getFlareLaneNotificationFromUNNotificationContent(_ notificationContent: UNNotificationContent) -> FlareLaneNotification? {
    guard let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUserInfo(userInfo: notificationContent.userInfo) else {
      return nil
    }

    return flarelaneNotification
  }

  /// JSON-serializable representation for the cross-platform bridge.
  ///
  /// Pre-compute every derived value here so cross-platform consumers (RN/Flutter) can stay
  /// read-only — they only declare fields, never reproduce branching logic. Keeps the notion
  /// of "what was clicked / where to go" pinned to the native source of truth.
  ///
  /// Returns `[String: Any]` (never `Optional<Any>`) so `JSONSerialization` accepts the
  /// dictionary. Optional fields are omitted when nil instead of carrying `Optional.none`
  /// values, which `isValidJSONObject` rejects and which would crash `data(withJSONObject:)`
  /// via NSException.
  public func toDictionary() -> [String: Any] {
    let clicked = clickedButton
    var dict: [String: Any] = [
      "id": id,
      "body": body
    ]
    if let title = title { dict["title"] = title }
    if let url = url { dict["url"] = url }
    if let imageUrl = imageUrl { dict["imageUrl"] = imageUrl }
    if let data = data { dict["data"] = data }
    if let buttons = buttonsList() { dict["buttons"] = buttons }
    if let clickedButtonIndex = clickedButtonIndex { dict["clickedButtonIndex"] = clickedButtonIndex }
    if let clicked = clicked {
      var item: [String: Any] = ["label": clicked.label]
      if let link = clicked.link { item["link"] = link }
      dict["clickedButton"] = item
    }
    if let clickedUrl = clickedUrl { dict["clickedUrl"] = clickedUrl }
    return dict
  }

  private func buttonsList() -> [[String: Any]]? {
    guard let buttons = buttons else { return nil }
    return buttons.map { button in
      var item: [String: Any] = ["label": button.label]
      if let link = button.link { item["link"] = link }
      return item
    }
  }
}
