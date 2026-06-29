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

  /// API that sends an event to FlareLane when a notification is received
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - type: Notification event type
  ///   - notificationId: NotificationId
  ///   - completion: Completion callback
  func sendEvent(deviceId: String, type: String, notificationId: String, data: [String: Any]? = nil, completion: @escaping (Error?) -> Void) {
    var body: [String: Any] = [
      "notificationId":notificationId,
      "deviceId": deviceId,
      "type": type,
      "createdAt": Date().toString(),
      "platform" : Globals.sdkPlatform
    ]

    let userId = Globals.userIdInUserDefaults
    if (userId != nil) {
      body["userId"] = userId
    }

    if let data = data, data.isEmpty == false {
      body["data"] = data
    }

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
  func trackEvent(deviceId: String, type: String, data: [String: Any]?, completion: @escaping (Error?) -> Void) {
    let userId = Globals.userIdInUserDefaults
    
    let subjectType = userId != nil ? "user": "device"
    let subjectId = userId ?? deviceId
    
    var event: [String: Any] = [
      "subjectType": subjectType,
      "subjectId": subjectId,
      "type": type,
      "createdAt": Date().toString(),
      "platform": Globals.sdkPlatform,
      "deviceId": deviceId
    ]

    if (data != nil) {
      event["data"] = data
    }
    
    if (userId != nil) {
      event["userId"] = userId
    }

    request.post(path: "/events-v2", body: ["events": [event]]) { (response, error) in
      completion(error)
    }
  }
    
  /// API to set user attributes
  /// - Parameters:
  ///   - deviceId: FlareLane deviceId
  ///   - userId: FlareLane userId (required by backend)
  ///   - attributes: User attribute key-value pairs (name/email/phoneNumber/dob/timeZone/country/language)
  func setUserAttributes(deviceId: String, userId: String, attributes: [String: Any], completion: @escaping (Error?) -> Void) {
    var body: [String: Any?] = attributes
    body["deviceId"] = deviceId
    body["userId"] = userId

    request.patch(path: "/user-attributes", body: body) { (_, error) in
      completion(error)
    }
  }

  func getInAppMessages(deviceId: String, group: String, data: [String: Any]?, completionHandler: @escaping (Result<[String: Any], Error>) -> Void) {
    request.post(
      path: "/devices/\(deviceId)/in-app-messages",
      body: ["group": group, "data": data]
    ) { result, error in
      if let error {
        completionHandler(.failure(error))
        return
      }
      if let result {
        completionHandler(.success(result))
        return
      }
      // (result, error) == (nil, nil) is reachable: request build failure,
      // a 200 response whose body isn't JSON, or a URLSession completion that
      // delivers data=nil/error=nil under background + low-memory pressure
      // (observed on iOS 26 / iPhone 13 Pro Max). Fail gracefully instead of
      // crashing the host app.
      Logger.error("getInAppMessages: nil response with no error")
      completionHandler(.failure(Request.HTTPError.unexpectedNilResponse))
    }
  }
}
