// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RSRender",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "RSRender", targets: ["RSRender"])
    ],
    dependencies: [
        .package(path: "../RSCore"),
        .package(path: "../RSContent")
    ],
    targets: [
        .target(
            name: "RSRender",
            dependencies: ["RSCore", "RSContent"],
            path: "Sources/RSRender"
        ),
        .testTarget(
            name: "RSRenderTests",
            dependencies: ["RSRender"],
            path: "Tests/RSRenderTests"
        )
    ]
)
