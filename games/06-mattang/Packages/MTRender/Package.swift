// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTRender",
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
