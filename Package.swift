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
    ],
    targets: [
        .target(name: "FlareLane",
                dependencies: ["FlareLaneNotificationExtension",
                               "FlareLaneObjc",
                               "FlareLaneUtil",
                               "FlareLaneExtension"],
                path: "Sources/FlareLane"),
        .target(name: "FlareLaneNotificationExtension",
                dependencies: ["FlareLaneUtil",
                               "FlareLaneExtension"],
                path: "Sources/FlareLaneNotificationExtension"),
        .target(name: "FlareLaneExtension",
                path: "Sources/FlareLaneExtension"),
        .target(name: "FlareLaneUtil",
                dependencies: ["FlareLaneExtension"],
                path: "Sources/FlareLaneUtil"),
        .target(name: "FlareLaneObjc",
                dependencies: ["FlareLaneNotificationExtension"],
                path: "Sources/FlareLaneObjc",
                publicHeadersPath: "Include"),
    ],
    swiftLanguageVersions: [.v5]
)
