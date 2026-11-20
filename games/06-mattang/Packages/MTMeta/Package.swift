// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MTMeta",
    products: [
        .library(name: "MTMeta", targets: ["MTMeta"])
    ],
    dependencies: [
        .package(path: "../MTCore"),
        .package(path: "../MTContent"),
        .package(path: "../MTAI"),
    ],
    targets: [
        .target(
            name: "MTMeta",
            dependencies: [
                "MTCore", "MTContent", "MTAI",
            ]),
        .testTarget(name: "MTMetaTests", dependencies: ["MTMeta"]),
    ]
)
