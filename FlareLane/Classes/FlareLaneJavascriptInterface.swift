//
//  FlareLaneJavascriptInterface.swift
//  FlareLane
//  Created by jp on 1/24/24.
//

import WebKit

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneJavascriptInterface: NSObject, WKScriptMessageHandler {
    
    @objc public static let BRIDGE_NAME = "FlareLaneBridge"

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let method = body["method"] as? String else {
            return
        }
        
        switch method {
        case "setUserId":
            setUserId(body: body)
        case "setTags":
            setTags(body: body)
        case "trackEvent":
            trackEvent(body: body)
        default:
            Logger.error("userContentController() method not found")
            break
        }
    }
    
    private func setUserId(body: [String: Any]) {
        if (body.keys.contains("userId")) {
            let userId = body["userId"] as? String
            FlareLane.setUserId(userId: userId)
        } else {
            Logger.error("setUserId() userId not found")
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
