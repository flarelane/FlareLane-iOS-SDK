//
//  InAppMessageView.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UIKit
import WebKit

@available(iOSApplicationExtension, unavailable)
protocol InAppMessageViewDelegate: AnyObject {
  func messageViewDidFinishNavigation(_ messageView: InAppMessageView)
  func messageViewDidReceiveTap(_ messageView: InAppMessageView)
}

@available(iOSApplicationExtension, unavailable)
class InAppMessageView: UIView {
  
  struct Configuration {
    var usesPaddingForSafeArea: Bool
    var horizontalPadding: CGFloat
    static let `default`: Self = .init(usesPaddingForSafeArea: false, horizontalPadding: .zero)
  }
  
  weak var delegate: InAppMessageViewDelegate?
  
  private var webView: WKWebView?
  private var configuration: Configuration
  private let message: FlareLaneInAppMessage
  
  init(message: FlareLaneInAppMessage,
       javascriptInterface: InAppMessageJavascriptInterface,
       configuration: Configuration = .default) {
    self.message = message
    self.configuration = configuration
    super.init(frame: .zero)
    self.setupWebView(with: javascriptInterface)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupWebView(with javascriptInterface: InAppMessageJavascriptInterface) {
    
    let webViewConfiguration = WKWebViewConfiguration()
    webViewConfiguration.suppressesIncrementalRendering = true
    webViewConfiguration.websiteDataStore = .nonPersistent()
    
    // Disable double tap zoom
    let source: String = "var meta = document.createElement('meta');" +
      "meta.name = 'viewport';" +
      "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" +
      "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
    let zoomDisableScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    webViewConfiguration.userContentController.addUserScript(zoomDisableScript)
    webViewConfiguration.userContentController.add(
      javascriptInterface,
      name: InAppMessageJavascriptInterface.name
    )
    
    let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
    webView.navigationDelegate = self
    webView.backgroundColor = .clear
    webView.scrollView.showsVerticalScrollIndicator = false
    webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = configuration.usesPaddingForSafeArea ? .never : .automatic
    webView.scrollView.bounces = false
    webView.scrollView.delegate = self
    webView.isOpaque = false
    webView.alpha = 0
    #if DEBUG
    if #available(iOS 16.4, *) {
      webView.isInspectable = true
    }
    #endif
  
    self.addSubview(webView)
    webView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.topAnchor.constraint(equalTo: webView.topAnchor),
      self.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
      self.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
      self.trailingAnchor.constraint(equalTo: webView.trailingAnchor)
    ])
    self.webView = webView
  }
  
  func loadHTML(_ string: String) {
//    self.webView?.loadHTMLString(string, baseURL: nil)
    
    let myURL = URL(string:"https://minhyeok4dev.github.io/inapp4.html")
    var myRequest = URLRequest(url: myURL!)
    myRequest.cachePolicy = .reloadIgnoringLocalCacheData
    self.webView?.load(myRequest)
  }
  
  func dismiss() {
    webView?.stopLoading()
    UIView.animate(withDuration: 0.25) {
      self.webView?.alpha = 0
    } completion: { _ in
      self.removeFromSuperview()
      InAppMessageService.shared.dismissInAppMessage()
    }
  }
  
  func updateSafeAreaInsets() {
    
    guard let keyWindow = UIApplication.shared.keyWindow, let webView else { return }
    
    let top = keyWindow.safeAreaInsets.top
    let bottom = keyWindow.safeAreaInsets.bottom
    let right = keyWindow.safeAreaInsets.right + configuration.horizontalPadding
    let left = keyWindow.safeAreaInsets.left + configuration.horizontalPadding
    
    let jsScript = """
      document.documentElement.style.setProperty('--safe-area-inset-top', '\(top)px');
      document.documentElement.style.setProperty('--safe-area-inset-bottom', '\(bottom)px');
      document.documentElement.style.setProperty('--safe-area-inset-left', '\(left)px');
      document.documentElement.style.setProperty('--safe-area-inset-right', '\(right)px');
    """
    
    webView.evaluateJavaScript(jsScript, completionHandler: { (result, error) in
      if let error = error {
        Logger.verbose("Failed to update html safe area insets: \(error)")
      } else {
        Logger.verbose("Succeed update html safe area insets")
      }
    })
  }
  
}

@available(iOSApplicationExtension, unavailable)
extension InAppMessageView: UIGestureRecognizerDelegate {
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
}

@available(iOSApplicationExtension, unavailable)
extension InAppMessageView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
}

@available(iOSApplicationExtension, unavailable)
extension InAppMessageView: WKNavigationDelegate {
  
  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    
    self.delegate?.messageViewDidFinishNavigation(self)
    
    UIView.animate(withDuration: 0.25) {
      self.webView?.alpha = 1
    }
    
    if configuration.usesPaddingForSafeArea {
      updateSafeAreaInsets()
    }
    
  }
  
}
