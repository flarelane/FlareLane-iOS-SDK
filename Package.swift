// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlareLane",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "FlareLane",
            targets: ["FlareLane"]),
        .library(
            name: "FlareLaneExtension",
            targets: ["FlareLane"])
    ],
    targets: [
        .target(name: "FlareLane",
                path: "Sources/FlareLaneSwift")
    ],
    swiftLanguageVersions: [.v5]
)
