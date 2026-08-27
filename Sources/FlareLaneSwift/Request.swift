//
//  Request.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class Request {

  // MARK: - Retry policy (mirrors the Android SDK: same constants, same wording)

  // Transient failures are retried before the caller hears about them, so a
  // few seconds without network no longer loses the request outright.
  static let maxAttempts = 3

  // Total budget for one call, retries included. Kept under the
  // FlareLaneTaskManager timeout (10s) so a retrying request cannot outlive
  // the task slot that is waiting on it.
  static let retryDeadline: TimeInterval = 8.0

  /// A transient failure is worth another attempt; a rejection the server
  /// would simply repeat is not. -1 means no HTTP response ever arrived.
  /// Every other 4xx fails immediately, 410 (gone) included — it is the
  /// stop signal and must not be delayed by a backoff.
  static func shouldRetry(responseCode: Int, attempt: Int) -> Bool {
    if attempt >= maxAttempts { return false }
    if responseCode == -1 || responseCode >= 500 { return true }
    return responseCode == 408 || responseCode == 429
  }

  /// Half the base delay (1s, then 3s) plus a random share of the other half,
  /// so devices that lost connectivity together do not retry as one burst.
  static func delayMillis(attempt: Int) -> Int {
    let half = (attempt <= 1 ? 1000 : 3000) / 2
    return half + Int.random(in: 0...half)
  }

  /// Runs the request, retrying transient failures while the call stays inside
  /// its deadline, then hands the final (data, response, error) to the caller's
  /// existing completion logic unchanged. The URLRequest is reused verbatim, so
  /// every attempt puts the same bytes on the wire — the event id inside stays
  /// stable, which is what lets the backend deduplicate a resend.
  private func perform(_ request: URLRequest, label: String, idempotent: Bool,
                       deadline: Date? = nil, attempt: Int = 1,
                       handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
    let deadline = deadline ?? Date().addingTimeInterval(Self.retryDeadline)

    // Clamped to what is left of the call's deadline (floored so a nearly spent
    // budget does not degenerate into instant spurious failures), so a single
    // blocked attempt cannot spend more than the whole call was given.
    var request = request
    request.timeoutInterval = max(1.0, min(10.0, deadline.timeIntervalSinceNow))

    URLSession.shared.dataTask(with: request) { data, response, error in
      let responseCode = error == nil ? ((response as? HTTPURLResponse)?.statusCode ?? -1) : -1
      let delayMs = Self.delayMillis(attempt: attempt)

      if idempotent, Self.shouldRetry(responseCode: responseCode, attempt: attempt),
         Date().addingTimeInterval(TimeInterval(delayMs) / 1000) < deadline {
        Logger.verbose("Retrying \(label) in \(delayMs)ms"
                       + " (attempt \(attempt + 1)/\(Self.maxAttempts), status \(responseCode))")
        // asyncAfter rather than a sleep: the wait costs a timer, not a thread.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + TimeInterval(delayMs) / 1000) {
          self.perform(request, label: label, idempotent: idempotent,
                       deadline: deadline, attempt: attempt + 1, handler: handler)
        }
        return
      }

      handler(data, response, error)
    }.resume()
  }

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
    
    perform(request, label: "GET \(path)", idempotent: true) { (data, response, error) in
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

  }

  /// POSTs are only retried when the caller marks them idempotent — a POST
  /// that reached the server but lost its response would otherwise be applied
  /// twice. Opt in only when the request is a read in POST clothing, or when
  /// its body carries an id the backend can deduplicate on. GET/PATCH/DELETE
  /// are idempotent by contract here: PATCH bodies are absolute values
  /// (last-writer-wins), never increments.
  func post(path: String, body: [String: Any?], idempotent: Bool = false, completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.POST, path: path, body: body) else {
      // Surface an explicit failure to the caller so a malformed body doesn't
      // leave dependent tasks (event queue, NSE handlers) waiting forever.
      completion(nil, nil)
      return
    }
    
    Logger.verbose("POST Request - path:\(path) body:\(body.description))")
    
    perform(request, label: "POST \(path)", idempotent: idempotent) { (data, response, error) in
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

  }

  func patch(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.PATCH, path: path, body: body) else {
      completion(nil, nil)
      return
    }
    
    Logger.verbose("PATCH Request - path:\(path) body:\(body.description))")
    
    perform(request, label: "PATCH \(path)", idempotent: true) { (data, response, error) in
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

  }

  func delete(path: String, body: [String: Any?], completion: @escaping ([String: Any]?, Error?) -> Void) {
    guard let request = self.getRequestWithBody(method: WithBodyMethod.DELETE, path: path, body: body) else {
      completion(nil, nil)
      return
    }
    
    Logger.verbose("DELETE Request - path:\(path) body:\(body.description))")
    
    perform(request, label: "DELETE \(path)", idempotent: true) { (data, response, error) in
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
    
  }
  
}
