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
  }

  func getBaseURL () -> String? {
      guard let projectId = Globals.projectId else {
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

      let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      completion(responseObject, nil)
    }

    task.resume()
  }

  func post(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.POST, path: path, body: body) else {
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
        let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
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
        let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
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
        let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        completion(responseObject, nil)
      } else {
        Logger.error(String(data: data, encoding: .utf8) ?? "delete error")
        completion(nil, HTTPError.serverSideError(response.statusCode))

      }
    }

    task.resume()
  }

}
