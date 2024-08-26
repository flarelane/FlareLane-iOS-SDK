//
//  Logger.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation
import FlareLaneExtension

@objc public enum LogLevel: IntegerLiteralType {
  case none = 0
  case error = 1
  case verbose = 5
}

enum LogEvent: String {
  case error = "[‼️]"
  case verbose = "[💬]"
}

final public class Logger {
  static public func error( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
    if Globals.logLevel.rawValue >= LogLevel.error.rawValue {
      print("\(Date().toString()) [FlareLaneLogger]\(LogEvent.error.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
    }
  }
  
  static public func verbose( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
    if Globals.logLevel.rawValue >= LogLevel.verbose.rawValue {
      print("\(Date().toString()) [FlareLaneLogger]\(LogEvent.verbose.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
    }
  }
  
  private static func sourceFileName(filePath: String) -> String {
    let components = filePath.components(separatedBy: "/")
    return components.isEmpty ? "" : components.last!
  }
}

