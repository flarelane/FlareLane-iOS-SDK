//
//  ApsEnvironment.swift
//  FlareLane
//
//  Copyright © 2021 FlareLabs. All rights reserved.
//

import Foundation

final class ApsEnvironment: NSObject {
  static func getEnvironmentString() -> String {
    if let mobileProvision = getMobileProvision() {
      let entitlements = mobileProvision.object(forKey: "Entitlements") as? NSDictionary
      if let apsEnvironment = entitlements?["aps-environment"] as? NSString, apsEnvironment.isEqual(to: "development") {
        return "development"
      }
    }
    
    return "production"
  }
  
  static func getMobileProvision() -> NSDictionary? {
    var mobileProvision: NSDictionary? = nil
    
    let provisioningPath = Bundle.main.path(forResource:"embedded", ofType: "mobileprovision")
    
    if provisioningPath == nil {
      return nil
    }
    
    let binaryString: NSString?
    
    do {
      binaryString = try NSString(contentsOfFile: provisioningPath!, encoding: String.Encoding.isoLatin1.rawValue)
    } catch _ {
      return nil
    }
    
    let scanner = Scanner(string: binaryString! as String)
    
    var ok = scanner.scanUpTo("<plist", into: nil)
    
    if !ok {
      return nil
    }
    
    var plistString: NSString? = ""
    
    ok = scanner.scanUpTo("</plist>", into: &plistString)
    
    if !ok {
      return nil
    }
    
    let newString = (plistString! as String) + "</plist>"
    
    if let plistdata_latin1 = newString.data(using: .isoLatin1) {
      do {
        mobileProvision = try PropertyListSerialization.propertyList(from: plistdata_latin1, options: PropertyListSerialization.MutabilityOptions(), format: nil) as? NSDictionary
      }
      catch {
        return nil
      }
    }
    
    return mobileProvision
  }
}
