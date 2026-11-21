// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTAI",
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
