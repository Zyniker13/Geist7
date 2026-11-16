// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RSContent",
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
            path: "Sources/RSContent"
        ),
        .testTarget(
            name: "RSContentTests",
            dependencies: ["RSContent"],
            path: "Tests/RSContentTests"
        )
    ]
)
