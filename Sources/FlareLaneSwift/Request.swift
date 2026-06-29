//
//  Request.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class Request {
  
  enum WithBodyMethod: String {
    case POST
    case PATCH
    case DELETE
  }
  
  enum HTTPError: Error {
    case transportError(Error)
    case serverSideError(Int)
    /// URLSession callback delivered no data and no error, or the 200 body wasn't JSON.
    /// Observed on iOS under background + low-memory pressure where the system
    /// terminates an in-flight dataTask without surfacing an NSURLError.
    case unexpectedNilResponse
  }
  
  func getBaseURL () -> String? {
    guard let projectId = Globals.projectIdInUserDefaults else {
      Logger.error("Cannot request when FlareLane has not been initialized yet.")
      return nil
    }
    
    return "https://service-api.flarelane.com/internal/v1/projects/\(projectId)"
  }
  
  func getRequestSDKInfoHeaderValue() -> String {
    return "\(Globals.sdkType)-\(Globals.sdkVersion)"
  }
  
  func getRequest(path: String, parameters: [String: String]) -> URLRequest? {
    guard let baseURL = self.getBaseURL() else {
      return nil
    }
    
    var components = URLComponents(string: "\(baseURL)\(path)")!
    components.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    
    var request = URLRequest(url: components.url!)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(self.getRequestSDKInfoHeaderValue(), forHTTPHeaderField: "x-flarelane-sdk-info")
    
    return request
  }
  
  func getRequestWithBody(method: WithBodyMethod, path: String, body: [String: Any?]) -> URLRequest? {
    guard let baseURL = self.getBaseURL(),
          let url = URL(string: "\(baseURL)\(path)") else {
      return nil
    }

    // Pre-validate before `data(withJSONObject:)`: that call raises an NSException
    // (not a Swift error) on non-JSON-serializable input — NaN / Infinity / arbitrary
    // class instances — and `try?` cannot catch NSException. Without this guard a
    // malformed payload silently crashes the host app.
    guard JSONSerialization.isValidJSONObject(body) else {
      Logger.error("Invalid JSON object in request body: \(body)")
      return nil
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(self.getRequestSDKInfoHeaderValue(), forHTTPHeaderField: "x-flarelane-sdk-info")

    return request
  }
  
  // MARK: - Methods
  
  func get(path: String, parameters: [String: String], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequest(path: path, parameters: parameters) else {
      completion(nil, nil)
      return
    }
    
    Logger.verbose("GET Request - path:\(path) parameters:\(parameters.description))")
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data,
            let response = response as? HTTPURLResponse,
            (200 ..< 300) ~= response.statusCode,
            error == nil else {
        completion(nil, error)
        return
      }
      
      // `jsonObject(with:)` raises NSException on grossly malformed data; `try?` can't
      // catch that, so validate the decoded shape too before downcasting.
      guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(jsonObject),
            let responseObject = jsonObject as? [String: Any] else {
        Logger.error("Invalid JSON response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
        completion(nil, nil)
        return
      }
      completion(responseObject, nil)
    }

    task.resume()
  }

  func post(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.POST, path: path, body: body) else {
      // Surface an explicit failure to the caller so a malformed body doesn't
      // leave dependent tasks (event queue, NSE handlers) waiting forever.
      completion(nil, nil)
      return
    }
    
    Logger.verbose("POST Request - path:\(path) body:\(body.description))")
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {
        completion(nil, error)
        return
      }
      
      if ((200 ..< 300) ~= response.statusCode) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(jsonObject),
              let responseObject = jsonObject as? [String: Any] else {
          Logger.error("Invalid JSON response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
          completion(nil, nil)
          return
        }
        completion(responseObject, nil)
      } else {
        Logger.error(String(data: data, encoding: .utf8) ?? "post error")
        completion(nil, HTTPError.serverSideError(response.statusCode))
      }
    }

    task.resume()
  }

  func patch(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.PATCH, path: path, body: body) else {
      completion(nil, nil)
      return
    }
    
    Logger.verbose("PATCH Request - path:\(path) body:\(body.description))")
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {
        completion(nil, error)
        return
      }
      
      if ((200 ..< 300) ~= response.statusCode) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(jsonObject),
              let responseObject = jsonObject as? [String: Any] else {
          Logger.error("Invalid JSON response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
          completion(nil, nil)
          return
        }
        completion(responseObject, nil)
      } else {
        Logger.error(String(data: data, encoding: .utf8) ?? "patch error")
        completion(nil, HTTPError.serverSideError(response.statusCode))
      }
    }

    task.resume()
  }

  func delete(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.DELETE, path: path, body: body) else {
      completion(nil, nil)
      return
    }
    
    Logger.verbose("DELETE Request - path:\(path) body:\(body.description))")
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {
        completion(nil, error)
        return
      }
      
      if ((200 ..< 300) ~= response.statusCode) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(jsonObject),
              let responseObject = jsonObject as? [String: Any] else {
          Logger.error("Invalid JSON response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
          completion(nil, nil)
          return
        }
        completion(responseObject, nil)
      } else {
        Logger.error(String(data: data, encoding: .utf8) ?? "delete error")
        completion(nil, HTTPError.serverSideError(response.statusCode))

      }
    }
    
    task.resume()
  }
  
}
