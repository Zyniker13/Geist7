// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MTRender",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "MTRender", targets: ["MTRender"])
    ],
    dependencies: [
        .package(path: "../MTCore")
    ],
    targets: [
        .target(name: "MTRender", dependencies: ["MTCore"]),
        .testTarget(name: "MTRenderTests", dependencies: ["MTRender"]),
    ]
)
