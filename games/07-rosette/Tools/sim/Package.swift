// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "sim",
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
