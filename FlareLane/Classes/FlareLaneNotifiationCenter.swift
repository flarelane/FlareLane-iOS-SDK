//
//  FlareLaneNotifiationCenter.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
  @objc static public let shared = FlareLaneNotificationCenter()
  
  // MARK: - Delegate Methods
  
  /// To handle notification clicked
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Logger.verbose("INVOKED")
    
    if let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(response.notification.request.content) {
      if Globals.projectId == nil {
        Logger.verbose("projectId is nil. Too early clicked? process later when cold start.")
        ColdStartNotificationManager.coldStartNotification = notification
      } else if (ColdStartNotificationManager.coldStartNotification?.id == notification.id) {
        // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
        Logger.verbose("ColdStartNotification is exists. skip didReceive")
      } else {
        Logger.verbose("Clicked user notification.")
        EventService.createClicked(notification: notification)
      }
      
      if let urlString = notification.url, let url = URL(string: urlString), let scheme = url.scheme {
        switch scheme {
        case "http", "https":
          presentWebView(url: url)
        default:
          presentApplication(url: url)
        }
      }
      
    }
    completionHandler()
  }
  
  /// To handle notification foreground received
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(notification.request.content) {
      if let flarelane_dismiss_foreground_notification = flarelaneNotification.data?["flarelane_dismiss_foreground_notification"] as? String,
         flarelane_dismiss_foreground_notification == "true" {
        
        Logger.verbose("notification dismissed cause flarelane_dismiss_foreground_notification is true.")
        return
      }
      
      let event = FlareLaneNotificationReceivedEvent(UIApplication.shared, notification: flarelaneNotification, completionHandler: completionHandler)
      
      if let handler = EventHandlers.notificationForegroundReceived {
        Logger.verbose("notificationForegroundReceivedHandler exists, you can control the display timing.")
        handler(event)
      } else {
        event.display()
      }
    }
  }
}

extension FlareLaneNotificationCenter {
  
  func presentWebView(url: URL) {
    guard let topViewController = getTopViewController() else {
      return
    }
    
    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { hasApp in
      if hasApp == false {
        let webViewController = UINavigationController(rootViewController: WebViewController(url: url))
        webViewController.modalPresentationStyle = .pageSheet
        topViewController.present(webViewController, animated: true, completion: nil)
      }
    }
  }
  
  private func getTopViewController(_ baseViewController: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
    
    if let navigationController = baseViewController as? UINavigationController {
      return getTopViewController(navigationController.visibleViewController)
    }
    
    if let tabBarController = baseViewController as? UITabBarController {
      if let selectedViewController = tabBarController.selectedViewController {
        return getTopViewController(selectedViewController)
      }
    }
    
    if let presentedViewController = baseViewController?.presentedViewController {
      return getTopViewController(presentedViewController)
    }
    
    return baseViewController
  }
  
}

extension FlareLaneNotificationCenter {
  
  func presentApplication(url: URL) {
    UIApplication.shared.open(url, options: [:])
  }
  
}
