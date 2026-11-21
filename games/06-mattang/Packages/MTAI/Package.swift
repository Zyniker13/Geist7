// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MTAI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "MTAI", targets: ["MTAI"])
    ],
    dependencies: [
        .package(path: "../MTCore")
    ],
    targets: [
        .target(name: "MTAI", dependencies: ["MTCore"]),
        .testTarget(name: "MTAITests", dependencies: ["MTAI", "MTCore"]),
    ]
)
