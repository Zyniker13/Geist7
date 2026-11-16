// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSAI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "RSAI", targets: ["RSAI"])
    ],
    dependencies: [
        .package(path: "../RSCore"),
        .package(path: "../RSContent")
    ],
    targets: [
        .target(
            name: "RSAI",
            dependencies: ["RSCore", "RSContent"],
            path: "Sources/RSAI"
        ),
        .testTarget(
            name: "RSAITests",
            dependencies: ["RSAI"],
            path: "Tests/RSAITests"
        )
    ]
)
