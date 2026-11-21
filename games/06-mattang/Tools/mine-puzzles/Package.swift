// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mine-puzzles",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../../Packages/MTAI"),
        .package(path: "../../Packages/MTCore"),
        .package(path: "../../Packages/MTContent"),
    ],
    targets: [
        .executableTarget(
            name: "mine-puzzles",
            dependencies: [
                .product(name: "MTAI", package: "MTAI"),
                .product(name: "MTCore", package: "MTCore"),
                .product(name: "MTContent", package: "MTContent"),
            ],
            path: "Sources/mine-puzzles"
        )
    ]
)
