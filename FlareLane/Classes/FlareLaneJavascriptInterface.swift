//
//  FlareLaneJavascriptInterface.swift
//  FlareLane
//

import WebKit

@objc class FlareLaneJavascriptInterface: NSObject, WKScriptMessageHandler {

    private func setUserId(userId: String) {
        FlareLane.setUserId(userId: userId)
    }
    
    private func setTags(jsonString: String) {
        if let jsonData = jsonString.data(using: .utf8),
           let tags = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            FlareLane.setTags(tags: tags)
        }
    }
    
    private func trackEvent(type: String, jsonString: String) {
        if let jsonData = jsonString.data(using: .utf8),
           let data = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            FlareLane.trackEvent(type, data: data)
        }
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
              if let jsonString = body["jsonString"] as? String {
                  setTags(jsonString: jsonString)
              }
          case "trackEvent":
              if let type = body["type"] as? String,
                 let jsonString = body["jsonString"] as? String {
                  trackEvent(type: type, jsonString: jsonString)
              }
          default:
              break
          }
    }
}
