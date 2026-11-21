// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MTContent",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "MTContent", targets: ["MTContent"])
    ],
    dependencies: [
        .package(path: "../MTCore")
    ],
    targets: [
        .target(
            name: "MTContent",
            dependencies: ["MTCore"],
            resources: [
                .process("Resources/Content")
            ]
        ),
        .testTarget(name: "MTContentTests", dependencies: ["MTContent"]),
    ]
)
