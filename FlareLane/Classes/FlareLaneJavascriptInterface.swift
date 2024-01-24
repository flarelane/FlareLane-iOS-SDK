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
            break
        }
    }
    
    private func setUserId(body: [String: Any]) {
        let userId = body["userId"] as? String
        Logger.verbose("setUserId() userId=\(userId ?? "nil")")
        FlareLane.setUserId(userId: body["userId"] as? String)
    }
    
    private func setTags(body: [String: Any]) {
        if let tags = body["tags"] as? [String: Any] {
            Logger.verbose("setTags() tags=\(tags)")
            FlareLane.setTags(tags: tags)
        }
    }
    
    private func trackEvent(body: [String: Any]) {
        if let type = body["type"] as? String {
            let data = body["data"] as? [String: Any]
            Logger.verbose("trackEvent() type=\(type), data=\(data != nil ? "\(data!)" : "nil")")
            FlareLane.trackEvent(type, data: data)
        }
    }
}
