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
        guard let inAppMessagesData = data["data"] as? [[String: Any]],
              let firstInAppMessageData = inAppMessagesData.first else {
          Logger.verbose("Requested in app messages are empty.")
          return
        }
        
        guard let firstInAppMessage = InAppMessage(dictionary: firstInAppMessageData) else {
          Logger.error("Failed to decode in app message data")
          return
        }
        
        self.show(message: firstInAppMessage)
        
      case let .failure(error):
        Logger.error("Failed to get in app messages: \(error.localizedDescription)")
      }
    }
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
      
    let window: UIWindow
    
    if self.window == nil {
      window = UIWindow(frame: UIScreen.main.bounds)
      window.windowLevel = .alert
        
      // Set active window scene
      if #available(iOS 13.0, *) {
        window.windowScene = UIApplication.shared.connectedScenes
          .compactMap {
              guard let scene = $0 as? UIWindowScene, scene.activationState == .foregroundActive else {
                  return nil
              }
              return scene
          }
          .first
      }
      self.window = window
    } else {
      window = self.window!
    }
    
    window.rootViewController = viewController
    window.backgroundColor = .clear
    window.isOpaque = false
    window.clipsToBounds = true
    
    // TODO: Determine if animation should be included.
    if #available(iOS 15.0, *) {
      UIView.animate(withDuration: 0.25) {
        window.isHidden = false
      }
    } else {
      window.isHidden = false
    }
  }
  
}
