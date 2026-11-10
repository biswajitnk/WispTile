// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "WispTile",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WispTileCore", targets: ["WispTileCore"]),
        .executable(name: "WispTileApp", targets: ["WispTileApp"]),
        .executable(name: "wisptile", targets: ["WispTileCLI"])
    ],
    targets: [
        .target(
            name: "WispTileCore",
            path: "Sources/WispTileCore"
        ),
        .executableTarget(
            name: "WispTileApp",
            dependencies: ["WispTileCore"],
            path: "Sources/WispTileApp"
        ),
        .executableTarget(
            name: "WispTileCLI",
            dependencies: ["WispTileCore"],
            path: "Sources/WispTileCLI"
        ),
        .testTarget(
            name: "WispTileCoreTests",
            dependencies: ["WispTileCore"],
            path: "Tests/WispTileCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
