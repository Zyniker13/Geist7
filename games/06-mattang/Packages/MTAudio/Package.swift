// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MTAudio",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
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
