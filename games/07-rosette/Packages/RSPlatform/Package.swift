// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSPlatform",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "RSPlatform", targets: ["RSPlatform"])
    ],
    dependencies: [
        .package(path: "../RSCore")
    ],
    targets: [
        .target(
            name: "RSPlatform",
            dependencies: ["RSCore"],
            path: "Sources/RSPlatform"
        ),
        .testTarget(
            name: "RSPlatformTests",
            dependencies: ["RSPlatform"],
            path: "Tests/RSPlatformTests"
        )
    ]
)
