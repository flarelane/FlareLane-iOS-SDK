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
    Logger.verbose("Notification", "didReceive response invoked")

    defer {
      completionHandler()
    }
    
    if let notification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(response.notification.request.content) {
      // If an action button was tapped, response.actionIdentifier carries the button index
      // we set in the NSE ("0", "1", ...). Default/dismiss identifiers are passed through unchanged.
      let resolved: FlareLaneNotification
      if let idx = Int(response.actionIdentifier),
         response.actionIdentifier != UNNotificationDefaultActionIdentifier,
         response.actionIdentifier != UNNotificationDismissActionIdentifier {
        resolved = notification.withClickedButtonIdx(idx)
      } else {
        resolved = notification
      }

      if Globals.projectIdInUserDefaults == nil {
        Logger.verbose("Notification", "projectId is nil; deferring click to cold start")
        ColdStartNotificationManager.coldStartNotification = resolved
      } else {
        NotificationClickProcessor.shared.processNotificationClick(notification: resolved)
      }
    }
  }
  
  /// To handle notification foreground received
  @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if let flarelaneNotification = FlareLaneNotification.getFlareLaneNotificationFromUNNotificationContent(notification.request.content) {
      
      BadgeManager.setCount(0)
      
      if let flarelane_dismiss_foreground_notification = flarelaneNotification.data?["flarelane_dismiss_foreground_notification"] as? String,
         flarelane_dismiss_foreground_notification == "true" {

        Logger.verbose("Notification", "foreground notification dismissed", ["reason": "flarelane_dismiss_foreground_notification"])
        // UNUserNotificationCenterDelegate contract: completionHandler MUST be invoked exactly
        // once on every willPresent call. Passing [] = "do not present this notification" while
        // still satisfying the contract — without it the OS holds the presentation queue and
        // eventually times out / logs a warning.
        completionHandler([])
        return
      }
      
      let event = FlareLaneNotificationReceivedEvent(UIApplication.shared, notification: flarelaneNotification, completionHandler: completionHandler)
      
      if let handler = EventHandlers.notificationForegroundReceived {
        Logger.verbose("Notification", "foreground handler exists, delegating display control")
        handler(event)
      } else {
        event.display()
      }
    }
  }
  
  @objc public func handleReceivedURL(url: URL) {
    let scheme = url.scheme
    Logger.verbose("Notification", "handling received url", ["url": url.absoluteString])
    
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
      Logger.verbose("Notification", "top view controller unavailable, retrying", ["context": "webView"])
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let topViewController = self.getTopViewController() {
          self.presentWebViewWithController(url: url, topViewController: topViewController)
        } else {
          // If still not available, fallback to Safari app
          Logger.verbose("Notification", "top view controller still unavailable, falling back to Safari app", ["context": "webView"])
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
      Logger.verbose("Notification", "top view controller unavailable, retrying", ["context": "safariView"])
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        if let topViewController = self.getTopViewController() {
          self.presentSafariViewWithController(url: url, topViewController: topViewController)
        } else {
          // If still not available, fallback to Safari app
          Logger.verbose("Notification", "top view controller still unavailable, falling back to Safari app", ["context": "safariView"])
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
    Logger.verbose("Notification", "opening url with UIApplication", ["url": url.absoluteString])
    
    // Add delay for cold start to ensure app is fully initialized
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      UIApplication.shared.open(url, options: [:]) { success in
        if success {
          Logger.info("Notification", "url opened", ["url": url.absoluteString])
        } else {
          Logger.error("Notification", "failed to open url", ["url": url.absoluteString])
        }
      }
    }
  }
}
