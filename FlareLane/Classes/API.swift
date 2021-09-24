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
  func updateDevice(deviceId: String, body: [String:Any?], completion: @escaping (String?, Error?) -> Void) {
    
    request.patch(path: "/devices/\(deviceId)", body: body) { (response, error) in
      if (error != nil) {
        completion(nil, error)
        return
      }
      
      let data = response?["data"] as? [String:Any]
      let deviceId = data?["id"] as? String
      completion(deviceId, error)
    }
  }
  
  /// API to delete tags of device
  /// - Parameters:
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
  
  /// API that sends an event to FlareKit when a notification is received
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
}
