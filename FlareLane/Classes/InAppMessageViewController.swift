//
//  InAppMessageViewController.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UIKit
import WebKit

protocol InAppMessageViewControllerDelegate: AnyObject {
  func messageViewControllerDidFinishLoading(_ message: InAppMessage)
}

class InAppMessageViewController: UIViewController {
  
  private let message: InAppMessage
  
  var messageView: InAppMessageView!
  
  weak var delegate: InAppMessageViewControllerDelegate?
  
  init(message: InAppMessage) {
    self.message = message
    super.init(nibName: nil, bundle: nil)
    
    let inAppMessageJavascriptInterface = InAppMessageJavascriptInterface()
    inAppMessageJavascriptInterface.delegate = self
    
    self.messageView = InAppMessageView(
      message: message,
      javascriptInterface: inAppMessageJavascriptInterface
    )
    self.messageView.translatesAutoresizingMaskIntoConstraints = false
    self.messageView.delegate = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.messageView.loadHTML(message.htmlString)
  }
  
  private func setupMessageViewConstraints() {
    self.view.addSubview(self.messageView)
    NSLayoutConstraint.activate([
      self.view.topAnchor.constraint(equalTo: self.messageView.topAnchor),
      self.view.bottomAnchor.constraint(equalTo: self.messageView.bottomAnchor),
      self.view.leadingAnchor.constraint(equalTo: self.messageView.leadingAnchor),
      self.view.trailingAnchor.constraint(equalTo: self.messageView.trailingAnchor)
    ])
  }
}

extension InAppMessageViewController: InAppMessageViewDelegate {
  
  func messageViewDidFinishNavigation(_ messageView: InAppMessageView) {
    self.delegate?.messageViewControllerDidFinishLoading(messageView.message)
    DispatchQueue.main.async {
      self.setupMessageViewConstraints()
    }
  }
  
  func messageViewDidReceiveTap(_ messageView: InAppMessageView) {
    self.messageView.dismiss()
  }
  
}

extension InAppMessageViewController: InAppMessageJavascriptInterfaceDelegate {
    
    func inAppMessageJavascriptInterface(didReceive event: InAppMessageJavascriptInterface.Event) {
        // TOOD: Handling javascript Interface events
    }
    
}
