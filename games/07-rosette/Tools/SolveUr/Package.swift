// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SolveUr",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(path: "../../Packages/RSCore")
    ],
    targets: [
        .executableTarget(
            name: "SolveUr",
            dependencies: [.product(name: "RSCore", package: "RSCore")],
            path: "."
        )
    ]
)
