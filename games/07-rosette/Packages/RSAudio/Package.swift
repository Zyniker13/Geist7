// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RSAudio",
    products: [
        .library(name: "RSAudio", targets: ["RSAudio"])
    ],
    dependencies: [
        .package(path: "../RSCore")
    ],
    targets: [
        .target(
            name: "RSAudio",
            dependencies: ["RSCore"],
            path: "Sources/RSAudio"
        ),
        .testTarget(
            name: "RSAudioTests",
            dependencies: ["RSAudio"],
            path: "Tests/RSAudioTests"
        )
    ]
)
