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
  
  private let queue = DispatchQueue(label: "com.flarelane.iam-js-interface")
  
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
    
    self.queue.async {
      switch method {
      case "setTags":
        self.setTags(body: body)
      case "trackEvent":
        self.trackEvent(body: body)
      case "openUrl":
        self.openURL(body: body)
      case "requestPushPermission":
        self.requestPushPermission()
      case "close":
        self.close()
      case "executeAction":
        self.executeAction(body: body)
      default:
        Logger.error("userContentController() method not found")
        break
      }
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
  
  func requestPushPermission() {
    FlareLane.isSubscribed { isSubscribed in
      if (isSubscribed) {
        self.close()
      } else {
        FlareLane.subscribe(fallbackToSettings: true) { _ in }
      }
    }
  }
  
  func openURL(body: [String: Any]) {
    guard let urlString = body["url"] as? String, let url = URL(string: urlString) else {
      Logger.error("openURL() URL is invalid")
      return
    }
    DispatchQueue.main.async {
      FlareLaneNotificationCenter.shared.handleReceivedURL(url: url)
    }
  }
  
  func close() {
    DispatchQueue.main.async {
      self.delegate?.inAppMessageJavascriptInterface(didReceive: .close)
    }
    // InAppMessage Window가 제거되기 전에 다른 이벤트가 처리되지 않게 딜레이를 추가한다
    Thread.sleep(forTimeInterval: 0.3)
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
