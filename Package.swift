// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FlareLane",
    products: [
        .library(name: "FlareLane", targets: ["FlareLane"]),
        .library(name: "FlareLaneObjC", targets: ["FlareLaneObjC"])
    ],
    targets: [
        .target(
          name: "FlareLane",
          path: "FlareLane/Classes",
          exclude: [
            "FlareLane.h",
            "ObjC"
          ]
        ),
        .target(
          name: "FlareLaneObjC",
          dependencies: ["FlareLane"],
          path: "FlareLane/Classes/ObjC"
        )
    ]
)
