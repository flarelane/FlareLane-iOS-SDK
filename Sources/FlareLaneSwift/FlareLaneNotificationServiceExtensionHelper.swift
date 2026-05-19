//
//  FlareLaneExtensionHelper.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UserNotifications
import MobileCoreServices

@objc public class FlareLaneNotificationServiceExtensionHelper: NSObject {
  @objc public static let shared = FlareLaneNotificationServiceExtensionHelper()
  
  var contentHandler: ((UNNotificationContent) -> Void)?
  var bestAttemptContent: UNMutableNotificationContent?
  
  @objc public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    Logger.verbose("INVOKED")

    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    if let badgeCount = bestAttemptContent?.badge as? Int {
      BadgeManager.setCount(badgeCount)
    } else {
      BadgeManager.setCount(BadgeManager.getCount() + 1)
    }

    guard let bestAttemptContent = bestAttemptContent,
          let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) else {
      deliverContent(self.bestAttemptContent ?? request.content)
      return
    }

    // Only Background. Cannot split background~foreground in extension.
    EventService.createBackgroundReceived(notificationId: flarelaneNotification.id)

    // Run image attachment and action-button category registration in parallel; deliver only after
    // both complete so the OS never presents the notification before its category is registered.
    let group = DispatchGroup()

    if flarelaneNotification.buttons?.isEmpty == false {
      group.enter()
      registerActionButtonsIfNeeded(notification: flarelaneNotification, content: bestAttemptContent) {
        group.leave()
      }
    }

    if let imageUrl = flarelaneNotification.imageUrl,
       let attachmentUrl = URL(string: imageUrl) {
      group.enter()
      let task = URLSession.shared.downloadTask(with: attachmentUrl) { downloadedUrl, response, error in
        defer { group.leave() }

        if let downloadedUrl = downloadedUrl,
           let attachment = try? UNNotificationAttachment(identifier: "flarelane_notification_attachment",
                                                          url: downloadedUrl,
                                                          options: [UNNotificationAttachmentOptionsTypeHintKey: kUTTypePNG]) {
          bestAttemptContent.attachments = [attachment]
        }
      }
      task.resume()
    }

    group.notify(queue: .global()) { [weak self] in
      self?.deliverContent(bestAttemptContent)
    }
  }


  @objc public func serviceExtensionTimeWillExpire() {
    Logger.verbose("INVOKED")

    if let bestAttemptContent = bestAttemptContent {
      deliverContent(bestAttemptContent)
    }
  }

  /// Invokes the OS-provided contentHandler exactly once. Either the async normal path
  /// (image download + category registration) or `serviceExtensionTimeWillExpire` may reach this
  /// first; whichever wins releases the handler so the other becomes a no-op.
  private func deliverContent(_ content: UNNotificationContent) {
    guard let handler = self.contentHandler else { return }
    self.contentHandler = nil
    handler(content)
  }
  
  @objc public func isFlareLaneNotification(_ request: UNNotificationRequest) -> Bool {
    if let _ = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(request.content) {
      return true
    }

    return false
  }

  // MARK: - Action Buttons

  static let categoryIdentifierPrefix = "flarelane_dynamic_"

  /// Build a UNNotificationCategory from the notification's button list and attach its identifier
  /// to the content. Each action's identifier is the button index ("0", "1", ...) so the click
  /// handler can recover `clickedButtonIdx` deterministically (matches the Android behavior).
  ///
  /// Garbage collection: we anchor each FlareLane-owned category to a delivered notification ID.
  /// On every NSE invocation we drop the categories whose notification is no longer in the
  /// Notification Center (dismissed by the user or expired). Categories registered by the host app
  /// or other libraries are left untouched. This bounds memory deterministically without any
  /// arbitrary size limit.
  ///
  /// `completion` is invoked once setNotificationCategories has finished so the caller can block
  /// contentHandler until the category is live — otherwise iOS may present the notification before
  /// the category is registered and the action buttons would be missing on first display.
  private func registerActionButtonsIfNeeded(notification: FlareLaneNotification, content: UNMutableNotificationContent, completion: @escaping () -> Void) {
    guard let buttons = notification.buttons, buttons.isEmpty == false else {
      completion()
      return
    }

    let categoryIdentifier = Self.categoryIdentifierPrefix + notification.id
    let actions: [UNNotificationAction] = buttons.enumerated().map { idx, button in
      // .foreground brings the app to the foreground on tap so the click handler can run normally
      // whether the app was background or terminated.
      return UNNotificationAction(
        identifier: "\(idx)",
        title: button.label,
        options: [.foreground]
      )
    }

    let category = UNNotificationCategory(
      identifier: categoryIdentifier,
      actions: actions,
      intentIdentifiers: [],
      options: []
    )

    // Attach the identifier synchronously — iOS resolves it lazily when presenting the
    // notification, so it only needs to be registered before contentHandler is invoked.
    content.categoryIdentifier = categoryIdentifier

    let center = UNUserNotificationCenter.current()
    let prefix = Self.categoryIdentifierPrefix

    center.getDeliveredNotifications { delivered in
      // Collect the FlareLane notification IDs currently visible in Notification Center plus the
      // incoming one (which hasn't been delivered yet).
      var liveIds = Set<String>()
      liveIds.insert(notification.id)
      for delivered in delivered {
        if let id = delivered.request.content.userInfo["notificationId"] as? String {
          liveIds.insert(id)
        }
      }

      center.getNotificationCategories { existing in
        var kept = Set<UNNotificationCategory>()
        for cat in existing {
          if cat.identifier.hasPrefix(prefix) {
            // FlareLane-owned: keep only if its notification is still alive.
            let owningId = String(cat.identifier.dropFirst(prefix.count))
            if liveIds.contains(owningId) && cat.identifier != categoryIdentifier {
              kept.insert(cat)
            }
          } else {
            // Categories registered by the host app or other SDKs — never touch.
            kept.insert(cat)
          }
        }
        kept.insert(category)
        center.setNotificationCategories(kept)
        Logger.verbose("Registered notification category \(categoryIdentifier) with \(buttons.count) action(s). Live FlareLane categories: \(kept.filter { $0.identifier.hasPrefix(prefix) }.count)")
        completion()
      }
    }
  }
}
