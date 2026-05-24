//
//  Logger.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

@objc public enum LogLevel: IntegerLiteralType {
  case none = 0
  case error = 1
  case verbose = 5
}

/// Single SDK-wide logger. Output prefix is unified across all four FlareLane SDKs to
/// `[FlareLane][LEVEL] message` so the same log line is recognizable on any platform.
///
/// Uses `NSLog` rather than `print` so the line shows up in the device's syslog —
/// visible via Console.app and `idevicesyslog` for production debugging, with the
/// timestamp / process / PID metadata that NSLog prepends automatically. Matches the
/// pattern used by OneSignal / Sentry / Firebase iOS SDKs.
final class Logger {
  static func verbose(_ object: Any) {
    if Globals.logLevel.rawValue >= LogLevel.verbose.rawValue {
      NSLog("%@", "[FlareLane][VERBOSE] \(object)")
    }
  }

  /// Pass `error` when reporting a caught exception. The Error's description
  /// (including `NSError`'s domain/code) is appended on its own line so the
  /// failure context is preserved alongside the action message.
  static func error(_ object: Any, error: Error? = nil) {
    if Globals.logLevel.rawValue >= LogLevel.error.rawValue {
      NSLog("%@", "[FlareLane][ERROR] \(object)")
      if let error = error {
        NSLog("%@", "[FlareLane][ERROR] cause=\(error)")
      }
    }
  }
}
