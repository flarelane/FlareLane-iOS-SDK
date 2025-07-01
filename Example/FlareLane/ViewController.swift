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
  let userId = "myuser@flarelane.com"
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    FlareLane.displayInApp(group: "home", data: ["data1": "d1", "data2": 2, "data3": nil])
  }

  @IBAction func ToggleUserID(_ sender: Any) {
    // You can give each device a unique string
    FlareLane.setUserId(userId: isSetUserId ? nil : userId)
    isSetUserId = !isSetUserId
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
  }

  @IBAction func TrackEvent(_ sender: Any) {
    FlareLane.trackEvent("test_event", data: ["test": "1234"])
  }

  @IBAction func isSubscribed(_ sender: Any) {
    FlareLane.isSubscribed() { isSubscribed in
      print("FlareLane.isSubscribed() - \(isSubscribed), isMainThread: \(Thread.isMainThread)")
    }
  }

  @IBAction func subscribe(_ sender: Any) {
    FlareLane.subscribe() { isSubscribed in
      print("FlareLane.subscribe() - \(isSubscribed), isMainThread: \(Thread.isMainThread)")
    }
  }

  @IBAction func unsubscribe(_ sender: Any) {
    FlareLane.unsubscribe() { isSubscribed in
      print("FlareLane.unsubscribe() - \(isSubscribed), isMainThread: \(Thread.isMainThread)")
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

