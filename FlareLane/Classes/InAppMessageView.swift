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
  weak var delegate: InAppMessageViewDelegate?
  
  private var webView: WKWebView?
  private let message: FlareLaneInAppMessage
  
  init(message: FlareLaneInAppMessage,
       javascriptInterface: InAppMessageJavascriptInterface) {
    self.message = message
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
    
    webViewConfiguration.userContentController.add(
      javascriptInterface,
      name: InAppMessageJavascriptInterface.name
    )
    
    let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
    webView.navigationDelegate = self
    webView.backgroundColor = .clear
    webView.scrollView.showsVerticalScrollIndicator = false
    webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    webView.scrollView.contentInsetAdjustmentBehavior = .automatic
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
    self.webView?.loadHTMLString(string, baseURL: nil)
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
    
  }
  
}
