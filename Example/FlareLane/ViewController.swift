//
//  ViewController.swift
//  FlareLane
//

import UIKit
import FlareLane

class ViewController: UIViewController {
  var isSetUserId = false
  var isSetTags = false
  var isSetUserAttributes = false
  let userId = "myuser@flarelane.com"
  
  /// Cycles verbose -> error -> none so the level gate can be checked on a device: at `.none`
  /// the SDK (including the Notification Service Extension) should print nothing at all.
  /// Added programmatically to keep the storyboard untouched.
  private let logLevels: [(LogLevel, String)] = [(.verbose, "verbose"), (.error, "error"), (.none, "none")]
  private var logLevelIndex = 0
  private lazy var logLevelButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()

    logLevelButton.setTitle("Log level (verbose)", for: .normal)
    logLevelButton.addTarget(self, action: #selector(cycleLogLevel), for: .touchUpInside)
    logLevelButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(logLevelButton)
    NSLayoutConstraint.activate([
      logLevelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      logLevelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
    ])
  }

  @objc private func cycleLogLevel() {
    logLevelIndex = (logLevelIndex + 1) % logLevels.count
    let (level, label) = logLevels[logLevelIndex]
    FlareLane.setLogLevel(level: level)
    logLevelButton.setTitle("Log level (\(label))", for: .normal)
  }

  /// Update both `setTitle` and `configuration?.title` so the new label sticks
  /// regardless of whether the button uses the legacy title or iOS 15+ button
  /// configuration.
  private func updateToggleTitle(_ sender: Any, prefix: String, state: Bool) {
    // state==true means currently set → next tap will delete; show (del). And vice versa.
    let title = "\(prefix) (\(state ? "del" : "set"))"
    if let button = sender as? UIButton {
      button.setTitle(title, for: .normal)
      button.configuration?.title = title
    }
  }

  @IBAction func ToggleUserID(_ sender: Any) {
    // You can give each device a unique string
    FlareLane.setUserId(userId: isSetUserId ? nil : userId)
    isSetUserId = !isSetUserId
    updateToggleTitle(sender, prefix: "Toggle UserID", state: isSetUserId)
  }

  @IBAction func ToggleTags(_ sender: Any) {
    if (isSetTags == false) {
      FlareLane.setTags(tags: ["age": 27, "gender": "men"])
      isSetTags = true
    } else {
      // To delete, NSNull() or nil is allowed
      FlareLane.setTags(tags: ["age": NSNull(), "gender": nil])
      isSetTags = false
    }
    updateToggleTitle(sender, prefix: "Toggle Tags", state: isSetTags)
  }

  @IBAction func TrackEvent(_ sender: Any) {
    FlareLane.trackEvent("test_event", data: ["test": "1234"])
  }

  @IBAction func SetUserAttributes(_ sender: Any) {
    if (isSetUserAttributes == false) {
      FlareLane.setUserAttributes(attributes: [
        "name": "Test User",
        "email": "test@example.com",
        "phoneNumber": "+821012345678",
        "dob": "1990-01-01",
        "timeZone": "Asia/Seoul",
        "country": "KR",
        "language": "ko"
      ])
      isSetUserAttributes = true
    } else {
      // Clear all attributes by setting them to NSNull.
      FlareLane.setUserAttributes(attributes: [
        "name": NSNull(),
        "email": NSNull(),
        "phoneNumber": NSNull(),
        "dob": NSNull(),
        "timeZone": NSNull(),
        "country": NSNull(),
        "language": NSNull()
      ])
      isSetUserAttributes = false
    }
    updateToggleTitle(sender, prefix: "Toggle User Attributes", state: isSetUserAttributes)
  }

  @IBAction func isSubscribed(_ sender: Any) {
    FlareLane.isSubscribed() { isSubscribed in
      print("FlareLane.isSubscribed() - \(isSubscribed), isMainThread: \(Thread.isMainThread)")
    }
  }

  // Separate buttons (not a toggle) so tests can force a known state without
  // tracking what the previous state was.
  @IBAction func subscribe(_ sender: Any) {
    FlareLane.subscribe() { subscribed in
      print("FlareLane.subscribe() - \(subscribed)")
    }
  }

  @IBAction func unsubscribe(_ sender: Any) {
    FlareLane.unsubscribe() { subscribed in
      print("FlareLane.unsubscribe() - \(subscribed)")
    }
  }
  
  @IBAction func displayInApp(_ sender: Any) {
    FlareLane.displayInApp(group: "home", data: ["data1": "d1", "data2": 2, "data3": nil])
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

