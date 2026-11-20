// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTPlatform",
    products: [
        .library(name: "MTPlatform", targets: ["MTPlatform"])
    ],
    dependencies: [
        .package(path: "../MTCore"),
        .package(path: "../MTMeta"),
        .package(path: "../MTContent"),
    ],
    targets: [
        .target(
            name: "MTPlatform",
            dependencies: [
                "MTCore", "MTMeta", "MTContent",
            ]),
        .testTarget(name: "MTPlatformTests", dependencies: ["MTPlatform"]),
    ]
)
