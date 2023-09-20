// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "FlareLane",
  platforms: [.iOS(.v11)],
  products: [
    .library(
      name: "FlareLane",
      targets: ["FlareLane"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "FlareLane",
      path: "FlareLane/Exports"
    )
  ],
  swiftLanguageVersions: [.v5]
)
