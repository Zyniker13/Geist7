// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sim",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../../Packages/RSCore")
    ],
    targets: [
        .executableTarget(
            name: "sim",
            dependencies: [.product(name: "RSCore", package: "RSCore")],
            path: "Sources/sim"
        )
    ]
)
