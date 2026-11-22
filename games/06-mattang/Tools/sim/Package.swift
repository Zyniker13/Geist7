// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../../Packages/MTCore"),
        .package(path: "../../Packages/MTAI"),
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [
                .product(name: "MTCore", package: "MTCore"),
                .product(name: "MTAI", package: "MTAI"),
            ],
            path: "Sources/sim"
        )
    ]
)
