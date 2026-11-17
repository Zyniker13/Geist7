// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSContent",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "RSContent", targets: ["RSContent"])
    ],
    dependencies: [
        .package(path: "../RSCore")
    ],
    targets: [
        .target(
            name: "RSContent",
            dependencies: ["RSCore"],
            path: "Sources/RSContent",
            resources: [
                .process("Resources/Content")
            ]
        ),
        .testTarget(
            name: "RSContentTests",
            dependencies: ["RSContent"],
            path: "Tests/RSContentTests"
        ),
    ]
)
