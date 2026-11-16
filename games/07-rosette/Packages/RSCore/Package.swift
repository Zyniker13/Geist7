// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RSCore",
    products: [
        .library(name: "RSCore", targets: ["RSCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RSCore",
            dependencies: [],
            path: "Sources/RSCore"
        ),
        .testTarget(
            name: "RSCoreTests",
            dependencies: ["RSCore"],
            path: "Tests/RSCoreTests"
        )
    ]
)
