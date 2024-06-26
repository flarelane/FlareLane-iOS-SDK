//
//  InAppMessageService.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import Foundation

struct InAppMessage {
  var id: String
  var htmlString: String
  
  init?(dictionary: [String: Any]) {
    guard let id = dictionary["id"] as? String,
          let htmlString = dictionary["htmlString"] as? String else {
      Logger.error("InAppMessage invalid dictionary format: \(dictionary)")
      return nil
    }
    self.id = id
    self.htmlString = htmlString
  }
}


final class InAppMessageService {
  
  static let shared = InAppMessageService()
  
  var window: UIWindow?
  var viewController: InAppMessageViewController?
  
  private init() {}
  
  func showInAppMessageIfNeeded() {
    API.shared.getInAppMessagesForTest { result in
      switch result {
      case let .success(data):
        self.processInAppMessages(data: data)
      case let .failure(error):
        Logger.error("Failed to get in app messages: \(error.localizedDescription)")
      }
    }
  }
  
  private func processInAppMessages(data: [String: Any]) {
    guard let inAppMessagesData = data["data"] as? [[String: Any]],
          let firstInAppMessageData = inAppMessagesData.first,
          let firstInAppMessage = InAppMessage(dictionary: firstInAppMessageData) else {
      Logger.error("No valid in-app messages or empty data")
      return
    }
    
    self.show(message: firstInAppMessage)
  }
  
  private func show(message: InAppMessage) {
    DispatchQueue.main.async {
      let viewController = InAppMessageViewController(message: message)
      self.viewController = viewController
      viewController.delegate = self
      viewController.view.setNeedsLayout()
    }
  }
  
  func dismissInAppMessage() {
    self.window?.isHidden = true
    self.window = nil
    self.viewController = nil
  }
}

extension InAppMessageService: InAppMessageViewControllerDelegate {
  
  func messageViewControllerDidFinishLoading(_ message: InAppMessage) {
    
    guard let viewController = self.viewController else { return }
    
    if self.window == nil {
      self.window = createAndConfigureWindow()
    }
    
    guard let window else { return }
    
    window.rootViewController = viewController
    
    if #available(iOS 15.0, *) {
      UIView.animate(withDuration: 0.25) {
        window.isHidden = false
      }
    } else {
      window.isHidden = false
    }
    
  }
  
  private func createAndConfigureWindow() -> UIWindow {
      let window = UIWindow(frame: UIScreen.main.bounds)
      window.windowLevel = .alert
      window.backgroundColor = .clear
      window.isOpaque = false
      window.clipsToBounds = true

      if #available(iOS 13.0, *) {
          window.windowScene = UIApplication.shared.connectedScenes
              .compactMap { $0 as? UIWindowScene }
              .first(where: { $0.activationState == .foregroundActive })
      }

      return window
  }
  
}
