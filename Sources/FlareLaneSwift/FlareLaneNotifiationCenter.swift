//
//  FlareLaneNotifiationCenter.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import UserNotifications
import SafariServices

@available(iOSApplicationExtension, unavailable)
@objc public class FlareLaneNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
  @objc static public let shared = FlareLaneNotificationCenter()
  
  // MARK: - Delegate Methods
  
  /// To handle notification clicked
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    Logger.verbose("INVOKED")
    
    defer {
      completionHandler()
    }
    
    if let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(response.notification.request.content) {
      // Resolve which action button (if any) the user tapped. The NSE registered each action with
      // its index as the identifier ("0", "1", ...), so anything that parses as an Int and isn't
      // the system default/dismiss identifier is a button click. The idx is baked into the
      // notification before we hand it off — no out-of-band parameter, mirroring Android.
      let resolved: FlareLaneNotification
      if response.actionIdentifier != UNNotificationDefaultActionIdentifier,
         response.actionIdentifier != UNNotificationDismissActionIdentifier,
         let idx = Int(response.actionIdentifier) {
        resolved = notification.withClickedButtonIndex(idx)
      } else {
        resolved = notification
      }

      let event = FlareLaneNotificationClickedEvent(notification: resolved)
      if Globals.projectIdInUserDefaults == nil {
        Logger.verbose("projectId is nil. Too early clicked? process later when cold start.")
        ColdStartNotificationManager.coldStartNotification = resolved
      } else {
        event.process()
      }
    }
  }
  
  /// To handle notification foreground received
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(notification.request.content) {
      
      BadgeManager.setCount(0)
      
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
  
  @objc public func handleReceivedURL(url: URL) {
    let scheme = url.scheme
    Logger.verbose("Handling received URL: \(url.absoluteString)")
    
    switch scheme {
    case "http", "https":
      // presentWebView(url: url)
      presentSafariView(url: url)
      // presentSafariApp(url: url)
    default:
      presentApplication(url: url)
    }
  }
  
  // MARK: Private Methods
  
  private func presentWebView(url: URL) {
    // Try to get top view controller immediately
    if let topViewController = getTopViewController() {
      presentWebViewWithController(url: url, topViewController: topViewController)
    } else {
      // If top view controller is not available (cold push scenario), retry with delay
      Logger.verbose("Top view controller not available, retrying with delay for cold push scenario")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let topViewController = self.getTopViewController() {
          self.presentWebViewWithController(url: url, topViewController: topViewController)
        } else {
          // If still not available, fallback to Safari app
          Logger.verbose("Top view controller still not available, falling back to Safari app")
          self.presentSafariApp(url: url)
        }
      }
    }
  }
  
  private func presentWebViewWithController(url: URL, topViewController: UIViewController) {
    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { hasApp in
      if hasApp == false {
        let webViewController = UINavigationController(rootViewController: WebViewController(url: url))
        webViewController.modalPresentationStyle = .pageSheet
        topViewController.present(webViewController, animated: true, completion: nil)
      }
    }
  }
  
  private func presentSafariView(url: URL) {
    // Try to get top view controller immediately
    if let topViewController = getTopViewController() {
      presentSafariViewWithController(url: url, topViewController: topViewController)
    } else {
      // If top view controller is not available (cold push scenario), retry with delay
      Logger.verbose("Top view controller not available, retrying with delay for cold push scenario")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let topViewController = self.getTopViewController() {
          self.presentSafariViewWithController(url: url, topViewController: topViewController)
        } else {
          // If still not available, fallback to Safari app
          Logger.verbose("Top view controller still not available, falling back to Safari app")
          self.presentSafariApp(url: url)
        }
      }
    }
  }
  
  private func presentSafariViewWithController(url: URL, topViewController: UIViewController) {
    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { hasApp in
      if hasApp == false {
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .pageSheet
        topViewController.present(safariViewController, animated: true, completion: nil)
      }
    }
  }
  
  private func presentSafariApp(url: URL) {
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
  
  private func presentApplication(url: URL) {
    Logger.verbose("Opening URL with UIApplication: \(url.absoluteString)")
    
    // Add delay for cold start to ensure app is fully initialized
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      UIApplication.shared.open(url, options: [:]) { success in
        if success {
          Logger.verbose("Successfully opened URL: \(url.absoluteString)")
        } else {
          Logger.verbose("Failed to open URL: \(url.absoluteString)")
        }
      }
    }
  }
}
