// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSMeta",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "RSMeta", targets: ["RSMeta"])
    ],
    dependencies: [
        .package(path: "../RSCore"),
        .package(path: "../RSContent"),
        .package(path: "../RSAI"),
    ],
    targets: [
        .target(
            name: "RSMeta",
            dependencies: ["RSCore", "RSContent", "RSAI"],
            path: "Sources/RSMeta"
        ),
        .testTarget(
            name: "RSMetaTests",
            dependencies: ["RSMeta"],
            path: "Tests/RSMetaTests"
        ),
    ]
)
