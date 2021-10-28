//
//  Request.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class Request {
  
  enum HTTPError: Error {
    case transportError(Error)
    case serverSideError(Int)
  }
  
  let baseURL: String = "https://service-api.flarelane.com/internal/v1/projects/\(Globals.projectId ?? "")"
  
  // MARK: - Methods
  
  func get(path: String, parameters: [String: String], completion: @escaping ([String: Any]?, Error?) -> Void) {
    Logger.verbose("GET Request - path:\(path) body:\(parameters.description))")
    
    let components = { () -> URLComponents in
      var components = URLComponents(string: "\(self.baseURL)\(path)")!
      components.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
      components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
      return components
    }()
    
    let request = { () -> URLRequest in 
      var request = URLRequest(url: components.url!)
      request.httpMethod = "GET"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.addValue("application/json", forHTTPHeaderField: "Accept")
      return request
    }()
    
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
    Logger.verbose("POST Request - path:\(path) body:\(body.description))")
    
    let request = { () -> URLRequest in
      var request = URLRequest(url: URL(string: "\(self.baseURL)\(path)")!)
      request.httpMethod = "POST"
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      return request
    }()
    
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
  
  func put(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    Logger.verbose("PUT Request - path:\(path) body:\(body.description))")
    
    let request = { () -> URLRequest in
      var request = URLRequest(url: URL(string: "\(self.baseURL)\(path)")!)
      request.httpMethod = "PUT"
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      return request
    }()
    
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
        Logger.error(String(data: data, encoding: .utf8) ?? "put error")
        completion(nil, HTTPError.serverSideError(response.statusCode))
      }
    }
    
    task.resume()
  }
  
  func patch(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    Logger.verbose("PATCH Request - path:\(path) body:\(body.description))")
    
    let request = { () -> URLRequest in
      var request = URLRequest(url: URL(string: "\(self.baseURL)\(path)")!)
      request.httpMethod = "PATCH"
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      return request
    }()
    
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
    Logger.verbose("DELETE Request - path:\(path) body:\(body.description))")
    
    let request = { () -> URLRequest in
      var request = URLRequest(url: URL(string: "\(self.baseURL)\(path)")!)
      request.httpMethod = "DELETE"
      request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      return request
    }()
    
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
