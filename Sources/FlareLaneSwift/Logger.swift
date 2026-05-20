//
//  Logger.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

/// Log severity. Higher rawValue = more verbose.
/// `none` blocks everything; `verbose` allows raw payload (HTTP body etc).
@objc public enum LogLevel: IntegerLiteralType {
  case none = 0
  case error = 1
  case info = 3
  case verbose = 5
}

/// Cross-SDK structured logger.
///
/// Output format: `[FlareLane][LEVEL][Module] message  key=value  key=value`
///
/// Writes via `NSLog` so logs are visible to `idevicesyslog`, macOS Console.app,
/// `log stream --device`, Xcode debugger, and CI/automation tooling alike.
final class Logger {
  static func error(_ module: String, _ message: String, _ kv: [String: Any]? = nil) {
    guard Globals.logLevel.rawValue >= LogLevel.error.rawValue else { return }
    NSLog("%@", format("ERROR", module, message, kv))
  }

  static func info(_ module: String, _ message: String, _ kv: [String: Any]? = nil) {
    guard Globals.logLevel.rawValue >= LogLevel.info.rawValue else { return }
    NSLog("%@", format("INFO", module, message, kv))
  }

  static func verbose(_ module: String, _ message: String, _ kv: [String: Any]? = nil) {
    guard Globals.logLevel.rawValue >= LogLevel.verbose.rawValue else { return }
    NSLog("%@", format("VERBOSE", module, message, kv))
  }

  // MARK: - Private

  private static func format(_ levelTag: String, _ module: String, _ message: String, _ kv: [String: Any]?) -> String {
    var line = "[FlareLane][\(levelTag)][\(module)] \(message)"
    if let kv = kv, !kv.isEmpty {
      let pairs = kv
        .sorted { $0.key < $1.key }
        .map { key, value in "\(key)=\(stringify(value))" }
        .joined(separator: " ")
      line += "  " + pairs
    }
    return line
  }

  private static func stringify(_ v: Any) -> String {
    if let s = v as? String { return s }
    if JSONSerialization.isValidJSONObject(v),
       let data = try? JSONSerialization.data(withJSONObject: v),
       let json = String(data: data, encoding: .utf8) {
      return json
    }
    return "\(v)"
  }
}
