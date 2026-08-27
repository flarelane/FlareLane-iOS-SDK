//
//  Request.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

/// The SDK's only HTTP entry point.
///
/// A request that fails for a transient reason — the connection dropped, the server answered 5xx —
/// is sent again a couple of times before the caller is told it failed. Callers see no difference:
/// they still get exactly one completion, only now after the retries are spent.
final class Request {

  typealias Completion = ([String: Any]?, Error?) -> Void

  /// See ``RetryBudget`` for what this does and does not bound.
  private static let retryBudget = RetryBudget(limit: 20)

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

  // MARK: - Building requests

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

  func get(path: String, parameters: [String: String], completion: @escaping Completion) {
    guard let request = self.getRequest(path: path, parameters: parameters) else {
      completion(nil, nil)
      return
    }

    Logger.verbose("GET Request - path:\(path) parameters:\(parameters.description))")
    perform(request, label: "GET \(path)", idempotent: true, completion: completion)
  }

  /// POSTs are only retried when the caller marks them `idempotent` — a POST that reached the
  /// server but lost its response would otherwise be applied twice. Callers may opt in when the
  /// request is a read in POST clothing, or when its body carries a deduplication id the backend
  /// can recognise. GET/PATCH/DELETE are idempotent by contract here: PATCH bodies are absolute
  /// values (last-writer-wins), never increments.
  func post(path: String, body: [String: Any?], idempotent: Bool = false, completion: @escaping Completion) {
    send(.POST, path: path, body: body, idempotent: idempotent, completion: completion)
  }

  func patch(path: String, body: [String: Any?], completion: @escaping Completion) {
    send(.PATCH, path: path, body: body, idempotent: true, completion: completion)
  }

  func delete(path: String, body: [String: Any?], completion: @escaping Completion) {
    send(.DELETE, path: path, body: body, idempotent: true, completion: completion)
  }

  private func send(_ method: WithBodyMethod, path: String, body: [String: Any?],
                    idempotent: Bool, completion: @escaping Completion) {
    guard let request = self.getRequestWithBody(method: method, path: path, body: body) else {
      // Surface an explicit failure to the caller so a malformed body doesn't
      // leave dependent tasks (event queue, NSE handlers) waiting forever.
      completion(nil, nil)
      return
    }

    Logger.verbose("\(method.rawValue) Request - path:\(path) body:\(body.description))")
    perform(request, label: "\(method.rawValue) \(path)", idempotent: idempotent, completion: completion)
  }

  // MARK: - Attempt loop

  /// Sends one attempt and either schedules the next one or hands the outcome to the caller.
  ///
  /// The `URLRequest` is passed along unchanged, so every attempt puts the exact same bytes on the
  /// wire — which is what lets the backend recognise a redelivered event and count it once.
  private func perform(_ request: URLRequest, label: String, idempotent: Bool, attempt: Int = 1,
                       completion: @escaping Completion) {
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      let statusCode = RetryPolicy.statusCode(for: response, error: error)

      guard idempotent, RetryPolicy.shouldRetry(statusCode: statusCode, attempt: attempt) else {
        self.finish(data: data, statusCode: statusCode, error: error, label: label, completion: completion)
        return
      }

      guard Self.retryBudget.tryAcquire() else {
        Logger.error("Retry budget full, giving up on \(label) with status \(statusCode)")
        self.finish(data: data, statusCode: statusCode, error: error, label: label, completion: completion)
        return
      }

      let delay = RetryPolicy.delay(attempt: attempt)
      Logger.verbose("Retrying \(label) in \(Int(delay * 1000))ms"
                     + " (attempt \(attempt + 1)/\(RetryPolicy.maxAttempts), status \(statusCode))")

      // asyncAfter rather than a sleep: the wait costs a timer, not a thread.
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
        Self.retryBudget.release()
        self.perform(request, label: label, idempotent: idempotent, attempt: attempt + 1, completion: completion)
      }
    }

    task.resume()
  }

  /// Turns a finished attempt into the `(response, error)` pair callers have always received.
  private func finish(data: Data?, statusCode: Int, error: Error?, label: String,
                      completion: Completion) {
    if let error = error {
      completion(nil, error)
      return
    }

    guard statusCode != RetryPolicy.noResponse else {
      // Nothing came back at all. Observed on iOS under background + low-memory pressure, where
      // the system terminates an in-flight dataTask without surfacing an NSURLError. Reported as
      // an error so callers do not mistake it for success and log a delivery that never happened.
      Logger.error("\(label) finished without a response.")
      completion(nil, HTTPError.unexpectedNilResponse)
      return
    }

    // Status-only decisions come before the body unwrap: an error status must keep its code even
    // when the reply carried no body, and 204/205 are defined to carry none at all.
    guard (200 ..< 300) ~= statusCode else {
      Logger.error("\(label) failed with status \(statusCode): "
                   + (data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"))
      completion(nil, HTTPError.serverSideError(statusCode))
      return
    }

    if statusCode == 204 || statusCode == 205 {
      completion([:], nil)
      return
    }

    guard let data = data else {
      Logger.error("\(label) returned \(statusCode) with no body.")
      completion(nil, HTTPError.unexpectedNilResponse)
      return
    }

    // `jsonObject(with:)` raises NSException on grossly malformed data; `try?` can't
    // catch that, so validate the decoded shape too before downcasting.
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
          JSONSerialization.isValidJSONObject(jsonObject),
          let responseObject = jsonObject as? [String: Any] else {
      Logger.error("Invalid JSON response data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")
      completion(nil, HTTPError.unexpectedNilResponse)
      return
    }

    completion(responseObject, nil)
  }
}
