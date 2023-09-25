//
//  PermissionState.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

class PermissionState {
  var accepted: Bool = false
  var answeredPrompt: Bool = false
  var initialized: Bool = false
  var calledPromptForNotificationsBeforeIntialized: Bool = false;
}
