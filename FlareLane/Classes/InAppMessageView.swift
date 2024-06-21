//
//  InAppMessageView.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UIKit
import WebKit

protocol InAppMessageViewDelegate: AnyObject {
  func messageViewDidFinishNavigation(_ messageView: InAppMessageView)
  func messageViewDidReceiveTap(_ messageView: InAppMessageView)
}

class InAppMessageView: UIView {
  
  typealias ScriptMessageHandler = InAppMessageJavascriptInterfaceDelegate
  
  weak var delegate: InAppMessageViewDelegate?
  
  private var webView: WKWebView?
  
  let message: InAppMessage
  
  init(message: InAppMessage,
       javascriptInterface: InAppMessageJavascriptInterface) {
    self.message = message
    super.init(frame: .zero)
    self.setupWebView(with: javascriptInterface)
    self.setupTapGesture()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupWebView(with javascriptInterface: InAppMessageJavascriptInterface) {
    
    let configuration = WKWebViewConfiguration()
    configuration.suppressesIncrementalRendering = true
    configuration.userContentController.add(
      javascriptInterface,
      name: InAppMessageJavascriptInterface.name
    )
    
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    webView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
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
      if #available(iOS 13.0, *) {
        InAppMessageService.shared.window?.windowScene = nil
      }
      InAppMessageService.shared.window = nil
      InAppMessageService.shared.viewController = nil
    }
    
  }
  
  private func setupTapGesture() {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
    tapGesture.delegate = self
    self.addGestureRecognizer(tapGesture)
  }
  
  @objc private func handleTapGesture() {
    self.delegate?.messageViewDidReceiveTap(self)
  }
}

extension InAppMessageView: UIGestureRecognizerDelegate {
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
}

extension InAppMessageView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
}

extension InAppMessageView: WKNavigationDelegate {
  
  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    
    self.delegate?.messageViewDidFinishNavigation(self)
    
    UIView.animate(withDuration: 0.25) {
      self.webView?.alpha = 1
    }
    
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    
  }
  
}
