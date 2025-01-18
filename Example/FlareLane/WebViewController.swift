//
//  WebviewController.swift
//  FlareLane_Example
//
//  Created by jp on 1/30/24.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import UIKit
import WebKit
import FlareLane

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    @IBOutlet var webView: WKWebView!
    
    override func loadView() {
        super.loadView()
        webView = WKWebView(frame: self.view.frame)
        webView.uiDelegate = self
        self.view = self.webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.configuration.preferences.javaScriptEnabled = true
        
        // add FlareLane javascript interface
        let interface = FlareLaneJavascriptInterface(webView)
        webView.configuration.userContentController.add(
            interface,
            name: FlareLaneJavascriptInterface.BRIDGE_NAME
        )
        
        let request = URLRequest(url: URL(string: "https://minhyeok4dev.github.io/")!)
        webView.load(request)
    }
}
