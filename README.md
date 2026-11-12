# FlareLane

[![CI Status](https://img.shields.io/travis/62019543/FlareLane.svg?style=flat)](https://travis-ci.org/62019543/FlareLane)
[![Version](https://img.shields.io/cocoapods/v/FlareLane.svg?style=flat)](https://cocoapods.org/pods/FlareLane)
[![License](https://img.shields.io/cocoapods/l/FlareLane.svg?style=flat)](https://cocoapods.org/pods/FlareLane)
[![Platform](https://img.shields.io/cocoapods/p/FlareLane.svg?style=flat)](https://cocoapods.org/pods/FlareLane)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

FlareLane is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'FlareLane'
```

## Region

Projects live in one FlareLane region. The default is `us`, so existing integrations need no change.
Projects created in the Seoul region pass `"kr"`:

```swift
FlareLane.initWithLaunchOptions(launchOptions, projectId: "YOUR_PROJECT_ID", region: "kr")
```

Any other region label maps to `service-api.<region>.flarelane.com`. A value that cannot form a label
(empty, spaces, punctuation, starting with a digit) is logged and initialization is skipped rather than falling back to `us`.

## Author

FlareLabs

## License

FlareLane is available under the MIT license. See the LICENSE file for more info.
