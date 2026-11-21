// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTCore",
    products: [
        .library(name: "MTCore", targets: ["MTCore"])
    ],
    targets: [
        .target(name: "MTCore"),
        .testTarget(
            name: "MTCoreTests", dependencies: ["MTCore"],
            resources: [.copy("Fixtures")]),
    ]
)
