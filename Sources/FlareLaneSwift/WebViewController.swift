//
//  WebViewController.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import WebKit

@available(iOSApplicationExtension, unavailable)
final class WebViewController: UIViewController, WKNavigationDelegate {
  
  private var webView: WKWebView!
  private var url: URL!
  
  init(url: URL) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func loadView() {
    super.loadView()
    webView = WKWebView(frame: self.view.frame)
    webView.navigationDelegate = self
    self.edgesForExtendedLayout = []
    view = webView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if #available(iOS 13.0, *) {
      navigationItem.leftBarButtonItem = .init(image: UIImage(systemName: "xmark"), style: .done, target: self, action: #selector(closeWebView))
      let appearance = UINavigationBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = .systemGroupedBackground
      navigationController?.navigationBar.standardAppearance = appearance
      navigationController?.navigationBar.scrollEdgeAppearance = appearance
      navigationController?.navigationBar.compactAppearance = appearance
    } else {
      navigationItem.leftBarButtonItem = .init(barButtonSystemItem: .done, target: self, action: #selector(closeWebView))
      navigationController?.navigationBar.isTranslucent = false
      navigationController?.navigationBar.barTintColor = .lightGray
    }
    navigationController?.navigationBar.prefersLargeTitles = false
    
    loadURL(url)
  }
  
  private func loadURL(_ url: URL) {
    let request = URLRequest(url: url)
    webView.load(request)
  }
  
  @objc
  private func closeWebView() {
    dismiss(animated: true, completion: nil)
  }
  
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url, url.scheme != "http", url.scheme != "https" {
      UIApplication.shared.open(url, options: [:])
      decisionHandler(.cancel)
      return
    }
    decisionHandler(.allow)
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let host = webView.url?.host ?? ""
    self.navigationItem.title = host
  }
}

