// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTAudio",
    products: [
        .library(name: "MTAudio", targets: ["MTAudio"])
    ],
    dependencies: [
        .package(path: "../MTCore")
    ],
    targets: [
        .target(name: "MTAudio", dependencies: ["MTCore"]),
        .testTarget(name: "MTAudioTests", dependencies: ["MTAudio"]),
    ]
)
