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
  let tags: [String: Any] = ["age": 27, "gender": "men"]
  let userId = "myuser@flarelane.com"
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  @IBAction func ToggleUserID(_ sender: Any) {
    // You can give each device a unique string
    FlareLane.setUserId(userId: isSetUserId ? nil : userId)
    isSetUserId = !isSetUserId
  }
   
  @IBAction func ToggleTags(_ sender: Any) {
    if (isSetTags == false) {
      // Set tags
      // Tags make it easy to categorize specific devices
      FlareLane.setTags(tags: tags)
      isSetTags = true
    } else {
      // Delete tags
      FlareLane.deleteTags(keys: Array(tags.keys))
      isSetTags = false
    }
  }
  
  @IBAction func TrackEvent(_ sender: Any) {
    FlareLane.trackEvent("test_event", data: ["test": "1234"])
  }
  
  @IBAction func getTags() {
    FlareLane.getTags() { tags in
      print(tags ?? "nil", ", isMainThread: \(Thread.isMainThread)")
    }
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
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

