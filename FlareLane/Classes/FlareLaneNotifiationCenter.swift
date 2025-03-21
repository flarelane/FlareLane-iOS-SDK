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
      if Globals.projectIdInUserDefaults == nil {
        Logger.verbose("projectId is nil. Too early clicked? process later when cold start.")
        ColdStartNotificationManager.coldStartNotification = notification
      } else if (ColdStartNotificationManager.coldStartNotification?.id == notification.id) {
        // If the id of coldStartNotification is the same as notificationId, it stops to avoid duplicate execution
        Logger.verbose("ColdStartNotification is exists. skip didReceive")
      } else {
        Logger.verbose("Clicked user notification.")
        EventService.createClicked(notification: notification)
      }

      if let infoDictionary = Bundle.main.infoDictionary,
         let flarelane_dismiss_launch_url = infoDictionary["flarelane_dismiss_launch_url"] as? Bool, flarelane_dismiss_launch_url == true {
        Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url in Info.plist is YES.")
        return
      }

      if let flarelane_dismiss_launch_url = notification.data?["flarelane_dismiss_launch_url"] as? String, flarelane_dismiss_launch_url == "true" {
        Logger.verbose("launch url dismissed cause flarelane_dismiss_launch_url is true.")
        return
      }

      if let urlString = notification.url, let url = URL(string: urlString) {
        handleReceivedURL(url: url)
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
  
  func handleReceivedURL(url: URL) {
    let scheme = url.scheme
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

  private func presentSafariView(url: URL) {
    guard let topViewController = getTopViewController() else {
      return
    }

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
    UIApplication.shared.open(url, options: [:])
  }
}
