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
    
    enum Event {
        case requestPushPermission(fallbackToSettings: Bool)
        case openURL(url: URL)
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
        default:
            Logger.error("userContentController() method not found")
            break
        }
    }
    
    private func setTags(body: [String: Any]) {
        if let tags = body["tags"] as? [String: Any] {
            FlareLane.setTags(tags: tags)
        } else {
            Logger.error("setTags() tags not found")
        }
    }
    
    private func trackEvent(body: [String: Any]) {
        if let type = body["type"] as? String {
            let data = body["data"] as? [String: Any]
            FlareLane.trackEvent(type, data: data)
        } else {
            Logger.error("trackEvent() type not found")
        }
    }
    
}
