// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    dependencies: [
        // The game's core rules package, by relative path.
        .package(path: "Packages/DGCore")
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [.product(name: "DGCore", package: "DGCore")],
            path: "Tools/sim"
        )
    ]
)
