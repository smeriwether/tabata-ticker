// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TabataCorePackage",
    products: [
        .library(name: "TabataCore", targets: ["TabataCore"])
    ],
    targets: [
        .target(
            name: "TabataCore",
            path: "Shared"
        ),
        .testTarget(
            name: "TabataCoreTests",
            dependencies: ["TabataCore"],
            path: "Tests"
        )
    ]
)
