// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ExampleCLI",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
        .package(url: "https://github.com/JohnSundell/Ink", from: "0.5.0"),
        .package(url: "https://github.com/sushichop/Puppy", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "ExampleCLI",
            dependencies: [
                .product(name: "SwiftStore", package: "swift-store"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Rainbow",
                "Ink",
                "Puppy"
            ]
        )
    ]
)
