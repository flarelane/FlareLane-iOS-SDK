//
//  FlareLaneJavascriptInterface.swift
//  FlareLane
//  Created by jp on 1/24/24.
//

import WebKit

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneJavascriptInterface: NSObject, WKScriptMessageHandler {
    @objc private weak var webView: WKWebView?
    @objc public static let BRIDGE_NAME = "FlareLaneBridge"
  
    public init(_ webView: WKWebView) {
        self.webView = webView
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Validate the bridge payload before downstream consumers attempt to
        // re-serialize it: `isValidJSONObject` rejects NaN / Infinity / non-JSON
        // types that would otherwise escape `try?` and crash via NSException.
        guard let body = message.body as? [String: Any],
              JSONSerialization.isValidJSONObject(body),
              let method = body["method"] as? String else {
            Logger.error("Invalid message body from JavaScript: \(message.body)")
            return
        }
        
        switch method {
        case "syncDeviceData":
            syncDeviceData()
        case "setUserId":
            setUserId(body: body)
        case "setTags":
            setTags(body: body)
        case "trackEvent":
            trackEvent(body: body)
        case "setUserAttributes":
            setUserAttributes(body: body)
        case "openUrl":
            openUrl(body: body)
        default:
            Logger.error("userContentController() method not found")
            break
        }
    }
  
    private func syncDeviceData() {
      // Emit unset identifiers as explicit `null`, not by omitting the key. The
      // web SDK applies `{ ...syncedDeviceData, ...data }` on receipt, so an
      // omitted key would keep a stale value on the JS side (e.g. after a native
      // logout `userId` would never clear). Native is the source of truth in
      // hybrid setups, so each call must convey the full identifier set —
      // including the absence of a value. NSNull is the JSONSerialization-
      // friendly null token, which also keeps the dict `isValidJSONObject`
      // compliant; without this, `[String: Optional<String>]` would fail the
      // check and the bridge would stay silent.
      let data: [String: Any] = [
        "platform": Globals.sdkPlatform,
        "deviceId": Globals.deviceIdInUserDefaults ?? NSNull(),
        "userId": Globals.userIdInUserDefaults ?? NSNull(),
        "projectId": Globals.projectIdInUserDefaults ?? NSNull()
      ]
      // Guard against NSException from `data(withJSONObject:)` should one of the
      // Globals ever be an unexpected non-JSON type — `try?` cannot recover from
      // that exception.
      guard JSONSerialization.isValidJSONObject(data) else {
        Logger.error("Invalid JSON object in syncDeviceData: \(data)")
        return
      }
      if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
         let jsonString = String(data: jsonData, encoding: .utf8) {
        let jsCode = "FlareLane.syncDeviceDataCallback(\(jsonString))"
        
        Logger.verbose("executed syncDeviceData from webView: \(jsCode)")
        
        webView?.evaluateJavaScript(jsCode, completionHandler: { result, error in
            if let error = error {
              print("Error getDeviceData.evaluateJavaScript: \(error)")
            }
        })
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

    private func setUserAttributes(body: [String: Any]) {
        if let attributes = body["attributes"] as? [String: Any] {
            // Mirror the syncDeviceData guard: reject NaN / Infinity / non-JSON types
            // here so a malformed payload can't crash via the downstream NSException
            // raised by `data(withJSONObject:)`.
            guard JSONSerialization.isValidJSONObject(attributes) else {
                Logger.error("Invalid JSON object in setUserAttributes: \(attributes)")
                return
            }
            FlareLane.setUserAttributes(attributes: attributes)
        } else {
            Logger.error("setUserAttributes() attributes not found")
        }
    }
  
    private func openUrl(body: [String: Any]) {
      if let urlString = body["url"] as? String,
         let url = URL(string: urlString) {
        DispatchQueue.main.async {
          self.webView?.load(URLRequest(url: url))
        }
      } else {
          Logger.error("openUrl() url not found")
      }
    }
}
