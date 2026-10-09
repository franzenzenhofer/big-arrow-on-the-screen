// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "big-arrow-on-the-screen",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "bigarrow", targets: ["bigarrow"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0")
    ],
    targets: [
        .target(name: "BigArrowCore"),
        .target(name: "BigArrowOverlay", dependencies: ["BigArrowCore"]),
        .target(name: "BigArrowTargeting", dependencies: ["BigArrowCore"]),
        .executableTarget(
            name: "bigarrow",
            dependencies: [
                "BigArrowCore",
                "BigArrowOverlay",
                "BigArrowTargeting",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "BigArrowCoreTests",
            dependencies: ["BigArrowCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["BigArrowCore", "BigArrowOverlay", "bigarrow"]
        )
    ]
)
