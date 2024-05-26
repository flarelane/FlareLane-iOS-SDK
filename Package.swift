// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlareLane",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "FlareLane",
            targets: ["FlareLaneObjc"]),
    ],
    targets: [
        .target(name: "FlareLaneSwift",
                path: "Sources/FlareLaneSwift"),
        .target(name: "FlareLaneObjc",
                dependencies: ["FlareLaneSwift"],
                path: "Sources/FlareLaneObjc",
                publicHeadersPath: "Include"),
    ],
    swiftLanguageVersions: [.v5]
)
