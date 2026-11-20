// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTContent",
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
