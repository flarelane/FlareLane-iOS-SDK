//
//  InAppMessageJavascriptInterface.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import WebKit

@available(iOSApplicationExtension, unavailable)
protocol InAppMessageJavascriptInterfaceDelegate: AnyObject {
  func inAppMessageJavascriptInterface(didReceive event: InAppMessageJavascriptInterface.Event)
}

@available(iOSApplicationExtension, unavailable)
class InAppMessageJavascriptInterface: NSObject, WKScriptMessageHandler {
  
  static let name: String = "FlareLaneIAMBridge"
  
  weak var delegate: InAppMessageJavascriptInterfaceDelegate?
  
  private let message: FlareLaneInAppMessage
  
  init(message: FlareLaneInAppMessage) {
    self.message = message
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
      close(body: body)
    case "executeAction":
      executeAction(body: body)
    default:
      Logger.error("userContentController() method not found")
      break
    }
  }
}

@available(iOSApplicationExtension, unavailable)
private extension InAppMessageJavascriptInterface {
  
  func setTags(body: [String: Any]) {
    guard let tags = body["tags"] as? [String: Any] else {
      Logger.error("setTags() tags not found")
      return
    }
    FlareLane.setTags(tags: tags)
  }
  
  func trackEvent(body: [String: Any]) {
    guard let type = body["type"] as? String else {
      Logger.error("trackEvent() type not found")
      return
    }
    let data = body["data"] as? [String: Any]
    FlareLane.trackEvent(type, data: data)
  }
  
  func requestPushPermission(fallbackToSettings: Bool) {
    FlareLane.isSubscribed { isSubscribed in
      if isSubscribed == false {
        FlareLane.subscribe(fallbackToSettings: fallbackToSettings) { _ in }
      }
    }
  }
  
  func openURL(body: [String: Any]) {
    guard let urlString = body["url"] as? String, let url = URL(string: urlString) else {
      Logger.error("openURL() URL is invalid")
      return
    }
    FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
  }
  
  func close(body: [String: Any]) {
    delegate?.inAppMessageJavascriptInterface(didReceive: .close)
  }
  
  func executeAction(body: [String: Any]) {
    guard let actionId = body["actionId"] as? String else {
      Logger.error("executeAction() actionId not found")
      return
    }
    DispatchQueue.main.async {
      EventHandlers.inAppMessageActionHandler?(self.message, actionId)
    }
  }
}
