// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
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
            path: "Tests/RSCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
