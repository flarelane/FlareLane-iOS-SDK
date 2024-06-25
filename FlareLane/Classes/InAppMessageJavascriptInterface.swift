//
//  InAppMessageJavascriptInterface.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import WebKit

protocol InAppMessageJavascriptInterfaceDelegate: AnyObject {
  func inAppMessageJavascriptInterface(didReceive event: InAppMessageJavascriptInterface.Event)
}

class InAppMessageJavascriptInterface: NSObject, WKScriptMessageHandler {
  
  static let name: String = "FlareLaneIAMBridge"
  
  weak var delegate: InAppMessageJavascriptInterfaceDelegate?
  
  private let messageId: String
  
  init(messageId: String) {
    self.messageId = messageId
  }
  
  enum Event {
    case close
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    
    guard let body = message.body as? [String: Any],
          let method = body["method"] as? String else {
      return
    }
    
    switch method {
    case "setTags":
      setTags(body: body)
    case "trackEvent":
      trackEvent(body: body)
    case "openUrl":
      openURL(body: body)
    case "requestPushPermission":
      requestPushPermission(fallbackToSettings: true)
    case "close":
      close()
    case "click":
      click(body: body)
    default:
      Logger.error("userContentController() method not found")
      break
    }
  }
}

private extension InAppMessageJavascriptInterface {
  
  func setTags(body: [String: Any]) {
    if let tags = body["tags"] as? [String: Any] {
      FlareLane.setTags(tags: tags)
    } else {
      Logger.error("setTags() tags not found")
    }
  }
  
  func trackEvent(body: [String: Any]) {
    if let type = body["type"] as? String {
      let data = body["data"] as? [String: Any]
      FlareLane.trackEvent(type, data: data)
    } else {
      Logger.error("trackEvent() type not found")
    }
  }
 
  func requestPushPermission(fallbackToSettings: Bool) {
    FlareLane.isSubscribed { isSubscribed in
      if isSubscribed == false {
        FlareLane.subscribe(fallbackToSettings: fallbackToSettings) { _ in }
      }
    }
  }
  
  func openURL(body: [String: Any]) {
    if let urlString = body["url"] as? String, let url = URL(string: urlString) {
      FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
    }
  }
  
  func close() {
    self.delegate?.inAppMessageJavascriptInterface(didReceive: .close)
  }
  
  
  func click(body: [String: Any]) {
    if let actionId = body["action_id"] as? String {
      if let handler = EventHandlers.inAppMessageClicked {
        DispatchQueue.main.async {
          handler(.init(messageId: self.messageId, actionId: actionId))
        }
      }
      FlareLane.trackEvent("iam_click", data: ["actionId": actionId])
    }
  }
}
