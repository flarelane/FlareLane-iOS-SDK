//
//  API.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class API {
  static let shared: API = API()
  
  private let request = Request()
  
  /// API to create device
  /// - Parameters:
  ///   - body: Body params
  ///   - completion: Completion callback
  func createDevice(body: [String:Any?], completion: @escaping (String?, Error?) -> Void) {
    
    request.post(path: "/devices", body: body) { (response, error) in
      if (error != nil) {
        completion(nil, error)
        return
      }
      
      let data = response?["data"] as? [String:Any]
      let deviceId = data?["id"] as? String
      completion(deviceId, error)
    }
  }
  
  /// API to update existing devices
  /// - Parameters:
  ///   - body: Body params
  ///   - completion: Completion callback
  func updateDevice(deviceId: String, body: [String:Any?], completion: @escaping ([String:Any?]?, Error?) -> Void) {
    
    request.patch(path: "/devices/\(deviceId)", body: body) { (response, error) in
      if (error != nil) {
        completion(nil, error)
        return
      }
      
      let device = response?["data"] as? [String:Any?]
      completion(device, error)
    }
  }
  
  /// API to get tags of device
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - completion: Completion callback
  func getTags(deviceId: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
    request.get(path: "/devices/\(deviceId)/tags", parameters: [:]) { (response, error) in
      if (error != nil) {
        completion(nil, error)
        return
      }
      
      let data = response?["data"] as? [String:Any]
      let tags = data?["tags"] as? [String: Any]
      completion(tags, error)
    }
  }
  
  /// API to delete tags of device
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - body: Tags to delete
  ///   - completion: Completion callback
  func deleteTags(deviceId: String, body: [String:Any?], completion: @escaping (String?, Error?) -> Void) {
    
    request.delete(path: "/devices/\(deviceId)/tags", body: body) { (response, error) in
      if (error != nil) {
        completion(nil, error)
        return
      }
      
      let data = response?["data"] as? [String:Any]
      let deviceId = data?["id"] as? String
      completion(deviceId, error)
    }
  }
  
  /// API that sends an event to FlareLane when a notification is received
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - type: Notification event type
  ///   - notificationId: NotificationId
  ///   - completion: Completion callback
  func sendEvent(deviceId: String, type: String, notificationId: String, completion: @escaping (Error?) -> Void) {
    let body = [
      "notificationId":notificationId,
      "deviceId": deviceId,
      "type": type,
      "createdAt": Date().toString(),
      "platform" : "ios"
    ]
    
    request.post(path: "/events", body: body) { (response, error) in
      completion(error)
    }
  }
  
  /// API that sends an event to FlareLane when a user event occurs.
  /// - Parameters:
  ///   - subjectType: device | userId
  ///   - subjectId: string
  ///   - type: event type
  ///   - data: event data
  func trackEvent(subjectType: String, subjectId: String, type: String, data: [String: Any]?, completion: @escaping (Error?) -> Void) {
    var event: [String: Any] = [
      "subjectType": subjectType,
      "subjectId": subjectId,
      "type": type,
      "createdAt": Date().toString(),
    ]
    
    if (data != nil) {
      event["data"] = data
    }
    
    request.post(path: "/events-v2", body: ["events": [event]]) { (response, error) in
      completion(error)
    }
  }
}
