//
//  FlareLaneNotification.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

@objc public class FlareLaneNotification: NSObject {
  // In case of structure, it is difficult to be compatible with Objective-C
  public var id: String
  public var body: String
  public var title: String?
  public var url: String?
  
  init(id: String, body: String, title: String?, url: String?) {
    self.id = id;
    self.body = body;
    self.title = title;
    self.url = url;
  }
}
