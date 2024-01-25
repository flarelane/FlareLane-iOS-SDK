//
//  FlareLaneJavascriptInterface.swift
//  FlareLane
//  Created by jp on 1/24/24.
//

import WebKit

@available(iOSApplicationExtension, unavailable)
@objc class FlareLaneJavascriptInterface: NSObject, WKScriptMessageHandler {
    
    private func setUserId(userId: String) {
        FlareLane.setUserId(userId: userId)
    }
    
    private func setTags(tags: [String: Any]) {
        FlareLane.setTags(tags: tags)
    }
    
    private func trackEvent(type: String, data: [String: Any]) {
        FlareLane.trackEvent(type, data: data)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let method = body["method"] as? String else {
            return
        }
        
        switch method {
        case "setUserId":
            if let userId = body["userId"] as? String {
                setUserId(userId: userId)
            }
        case "setTags":
            if let tags = body["tags"] as? [String: Any] {
                setTags(tags: tags)
            }
        case "trackEvent":
            if let type = body["type"] as? String,
               let data = body["data"] as? [String: Any] {
                trackEvent(type: type, data: data)
            }
        default:
            break
        }
    }
}
