// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../../Packages/MTCore")
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [.product(name: "MTCore", package: "MTCore")],
            path: "Sources/sim"
        )
    ]
)
