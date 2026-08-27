//
//  RetryPolicy.swift
//  FlareLane
//
//  Copyright © 2026 FlareLabs. All rights reserved.
//

import Foundation

/// Decides whether a failed request is worth sending again, and how long to wait first.
///
/// Deliberately free of networking types: the retry contract is the part most worth pinning down
/// with tests, and this way it can be exercised without a socket. Values match the Android SDK so
/// both platforms behave identically on the same network.
enum RetryPolicy {

  /// Status reported when a request never produced an HTTP response (DNS, connect, read, timeout).
  static let noResponse = -1

  /// Total attempts allowed per request, the first one included.
  static let maxAttempts = 3

  /// Base wait before attempt N+1, indexed by `attempt - 1`.
  private static let baseDelays: [TimeInterval] = [1.0, 3.0]

  /// A transient failure is worth another attempt; a rejection the server would simply repeat is not.
  ///
  /// - Parameters:
  ///   - statusCode: HTTP status, or ``noResponse`` when the request never got one.
  ///   - attempt: 1-based number of the attempt that just failed.
  static func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
    if attempt >= maxAttempts {
      return false
    }
    if statusCode == noResponse {
      return true // the connection never completed — the next one still might
    }
    if statusCode >= 500 {
      return true // server-side and typically short-lived
    }
    // Every other 4xx is a decision the server will reach again, 410 (gone) included.
    return statusCode == 408 || statusCode == 429
  }

  /// Half the base delay plus a random share of the other half.
  ///
  /// The random part matters: devices that lost connectivity together would otherwise come back in
  /// lockstep and retry as one burst.
  static func delay(attempt: Int, randomness: (ClosedRange<TimeInterval>) -> TimeInterval = { .random(in: $0) }) -> TimeInterval {
    let index = min(max(attempt, 1), baseDelays.count) - 1
    let half = baseDelays[index] / 2
    return half + randomness(0...half)
  }

  /// Maps a `URLSession` outcome onto the status the policy reasons about.
  ///
  /// A transport error means no response ever arrived, so it collapses to ``noResponse`` — the one
  /// case where the request is worth repeating without knowing what the server thinks.
  static func statusCode(for response: URLResponse?, error: Error?) -> Int {
    guard error == nil, let http = response as? HTTPURLResponse else {
      return noResponse
    }
    return http.statusCode
  }
}
