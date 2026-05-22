//
//  ViewController.swift
//  FlareLane
//

import UIKit
import FlareLane

class ViewController: UIViewController {
  var isSetUserId = false
  var isSubscribed = false
  var isSetTags = false
  var isSetUserAttributes = false
  let userId = "myuser@flarelane.com"
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    FlareLane.displayInApp(group: "home", data: ["data1": "d1", "data2": 2, "data3": nil])
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

  override func viewDidLoad() {
    super.viewDidLoad()
    // Reset titles to reflect initial false state.
    // (Storyboard titles are static; runtime sync keeps them in lockstep.)
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

  @IBAction func ToggleSubscribe(_ sender: Any) {
    if (isSubscribed == false) {
      FlareLane.subscribe() { subscribed in
        print("FlareLane.subscribe() - \(subscribed)")
        DispatchQueue.main.async {
          self.isSubscribed = subscribed
          self.updateToggleTitle(sender, prefix: "Toggle Subscribe", state: self.isSubscribed)
        }
      }
    } else {
      FlareLane.unsubscribe() { subscribed in
        print("FlareLane.unsubscribe() - \(subscribed)")
        DispatchQueue.main.async {
          self.isSubscribed = subscribed
          self.updateToggleTitle(sender, prefix: "Toggle Subscribe", state: self.isSubscribed)
        }
      }
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

