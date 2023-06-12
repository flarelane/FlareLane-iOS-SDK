//
//  ViewController.swift
//  FlareLane
//
//  Created by 62019543 on 09/24/2021.
//  Copyright (c) 2021 62019543. All rights reserved.
//

import UIKit
import FlareLane

class ViewController: UIViewController {
  var isSetUserId = false
  var isSubscribed = false
  var isSetTags = false
  let tags: [String: Any] = ["age": 27, "gender": "men"]
  let userId = "myuser@flarelane.com"
  @IBOutlet weak var textField: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    view.addGestureRecognizer(tapGesture)
  }
  
  @objc func dismissKeyboard() {
      view.endEditing(true)
  }
  
  @IBAction func ToggleUserID(_ sender: Any) {
    // You can give each device a unique string
    FlareLane.setUserId(userId: isSetUserId ? nil : userId)
    isSetUserId = !isSetUserId
  }
  
  @IBAction func ToggleIsSubscribed(_ sender: Any) {
    // Set subscribed or not
    // Even if notifications are turned on in the system, no notifications are sent if the subscription is false.
    FlareLane.setIsSubscribed(isSubscribed: isSubscribed)
    isSubscribed = !isSubscribed
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
  
  @IBAction func trackEvent(_ sender: UIButton) {
    let jsonString = textField.text
    
    if (jsonString == nil || jsonString == "") {
      return
    }
    
    guard let jsonData = jsonString?.data(using: .utf8) else {
      print("Failed to convert JSON string to Data.")
      return
    }
    
    do {
      if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
        guard let type = jsonObject["type"] as? String else {
          print("Event must have a type.")
          return
        }
        
        let data = jsonObject["data"] as? [String: Any]
        
        FlareLane.trackEvent(type: type, data: data)
      }
    } catch {
      print("Failed to json decode.");
    }
    
    textField.text = ""
    dismissKeyboard()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

