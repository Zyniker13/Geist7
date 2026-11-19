// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSPlatform",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "RSPlatform", targets: ["RSPlatform"])
    ],
    dependencies: [
        .package(path: "../RSCore"),
        .package(path: "../RSAI"),
        .package(path: "../RSContent"),
        .package(path: "../RSMeta"),
    ],
    targets: [
        .target(
            name: "RSPlatform",
            dependencies: ["RSCore", "RSAI", "RSMeta"],
            path: "Sources/RSPlatform"
        ),
        .testTarget(
            name: "RSPlatformTests",
            dependencies: ["RSPlatform", "RSAI", "RSContent", "RSMeta"],
            path: "Tests/RSPlatformTests"
        ),
    ]
)
