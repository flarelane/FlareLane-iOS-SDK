//
//  InAppMessageViewController.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UIKit
import WebKit

protocol InAppMessageViewControllerDelegate: AnyObject {
  func messageViewControllerDidFinishLoading(_ message: FlareLaneInAppMessage)
}

class InAppMessageViewController: UIViewController {
  
  private let message: FlareLaneInAppMessage
  private var messageView: InAppMessageView!
  
  weak var delegate: InAppMessageViewControllerDelegate?
  
  init(message: FlareLaneInAppMessage) {
    self.message = message
    super.init(nibName: nil, bundle: nil)
    self.setupInAppMessageView()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setupInAppMessageView() {
    let javascriptInterface = InAppMessageJavascriptInterface(message: self.message)
    javascriptInterface.delegate = self
    self.messageView = InAppMessageView(message: message, javascriptInterface: javascriptInterface)
    self.messageView.translatesAutoresizingMaskIntoConstraints = false
    self.messageView.delegate = self
    view.addSubview(self.messageView)
    NSLayoutConstraint.activate([
      self.messageView.topAnchor.constraint(equalTo: view.topAnchor),
      self.messageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      self.messageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      self.messageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.messageView.loadHTML(message.htmlString)
  }
}

extension InAppMessageViewController: InAppMessageViewDelegate {
  func messageViewDidFinishNavigation(_ messageView: InAppMessageView) {
    self.delegate?.messageViewControllerDidFinishLoading(message)
  }
  
  func messageViewDidReceiveTap(_ messageView: InAppMessageView) {
    self.messageView.dismiss()
  }
}

extension InAppMessageViewController: InAppMessageJavascriptInterfaceDelegate {
  func inAppMessageJavascriptInterface(didReceive event: InAppMessageJavascriptInterface.Event) {
    switch event {
    case .close:
      self.messageView.dismiss()
    }
  }
}
