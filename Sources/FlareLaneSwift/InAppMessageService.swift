//
//  InAppMessageService.swift
//  FlareLane
//
//  Copyright © 2024 FlareLabs. All rights reserved.
//

import UIKit

@available(iOSApplicationExtension, unavailable)
final class InAppMessageService {
  
  static let shared = InAppMessageService()
  
  var window: UIWindow?
  var viewController: InAppMessageViewController?
  
  private var isDisplaying: Bool = false
  
  private init() {}
  
  func showInAppMessageIfNeeded(group: String) {
    guard let deviceId = Globals.deviceIdInUserDefaults else {
      Logger.error("deviceId does not set.")
      return
    }
    
    if isDisplaying {
      Logger.verbose("InAppMessage is already displaying")
      return
    }
    
    API.shared.getInAppMessages(deviceId: deviceId, group: group) { result in
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
          let firstData = inAppMessagesData.first else {
      Logger.verbose("There is no displayable IAM")
      return
    }
    
    guard let messageId = firstData["id"] as? String,
          let htmlString = firstData["htmlString"] as? String else {
      Logger.error("Failed to process in app message: invalid data (\(firstData))")
      return
    }
    
    let message = FlareLaneInAppMessage(id: messageId, htmlString: htmlString)
    self.show(message: message)
  }
  
  private func show(message: FlareLaneInAppMessage) {
    DispatchQueue.main.async {
      let viewController = InAppMessageViewController(message: message)
      self.viewController = viewController
      viewController.delegate = self
      viewController.view.setNeedsLayout()
      self.isDisplaying = true
    }
  }
  
  func dismissInAppMessage() {
    DispatchQueue.main.async {
      self.window?.isHidden = true
      if #available(iOS 13.0, *) {
        self.window?.windowScene = nil
      }
      self.window = nil
      self.viewController = nil
      self.isDisplaying = false
    }
  }
}

@available(iOSApplicationExtension, unavailable)
extension InAppMessageService: InAppMessageViewControllerDelegate {
  
  func messageViewControllerDidFinishLoading(_ message: FlareLaneInAppMessage) {
    
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
