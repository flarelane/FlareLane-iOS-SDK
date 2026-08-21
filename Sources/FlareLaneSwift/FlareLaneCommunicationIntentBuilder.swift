//
//  FlareLaneCommunicationIntentBuilder.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Intents
import UserNotifications

/// Applies the chat-style (communication notification) rendering to notification content by
/// donating an INSendMessageIntent and returning `content.updating(from:)`.
///
/// Requires the HOST APP to have the Communication Notifications capability
/// (com.apple.developer.usernotifications.communication) and `NSUserActivityTypes` containing
/// `INSendMessageIntent` in its Info.plist. When those are missing, `updating(from:)` still
/// succeeds and iOS silently renders a normal notification — safe to attempt unconditionally.
@available(iOS 15.0, *)
enum FlareLaneCommunicationIntentBuilder {

  /// Returns content restyled as a communication notification, or the input content unchanged
  /// when the avatar is unavailable or the intent cannot be applied. Pure input → output
  /// (aside from the interaction donation) so it can be unit tested without a device.
  ///
  /// The avatar gate is deliberate product behavior, not just error handling: without an image
  /// the chat-style rendering shows a gray monogram bubble, which reads as broken for marketing
  /// pushes — a normal app-icon notification is the better fallback.
  static func apply(
    communication: FlareLaneNotificationCommunication,
    notificationId: String,
    threadId: String?,
    avatarData: Data?,
    to content: UNMutableNotificationContent
  ) -> UNNotificationContent {
    guard let avatarData = avatarData, avatarData.isEmpty == false else {
      Logger.verbose("No sender avatar available; delivering as a normal notification.")
      return content
    }

    let sender = INPerson(
      personHandle: INPersonHandle(value: communication.senderName, type: .unknown),
      nameComponents: nil,
      displayName: communication.senderName,
      image: INImage(imageData: avatarData),
      contactIdentifier: nil,
      customIdentifier: nil
    )

    let intent = INSendMessageIntent(
      recipients: nil,
      outgoingMessageType: .outgoingMessageText,
      content: content.body,
      speakableGroupName: nil,
      // Conversations reuse the grouping key so chat bubbles and thread grouping stay one concept.
      conversationIdentifier: threadId ?? notificationId,
      serviceName: nil,
      sender: sender,
      attachments: nil
    )

    // Donation feeds Siri suggestions / Focus breakthrough learning; rendering itself only needs
    // updating(from:). Fire-and-forget keeps the NSE free of another async wait, and the stable
    // identifier makes re-donation on duplicate delivery replace instead of accumulate.
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.identifier = notificationId
    interaction.direction = .incoming
    interaction.donate(completion: nil)

    do {
      return try content.updating(from: intent)
    } catch {
      Logger.error("Failed to apply communication notification style; delivering as a normal notification.", error: error)
      return content
    }
  }
}
