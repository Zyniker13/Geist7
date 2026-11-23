// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DGCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "DGCore", targets: ["DGCore"])
    ],
    targets: [
        .target(name: "DGCore"),
        .testTarget(
            name: "DGCoreTests", dependencies: ["DGCore"],
            resources: [.copy("Fixtures")]),
    ]
)
