// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgilitonShared",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9)
    ],
    products: [
        // Core functionality shared across all apps
        .library(
            name: "AgilitonCore",
            targets: ["AgilitonCore"]
        ),
        // Reusable UI components
        .library(
            name: "AgilitonUI",
            targets: ["AgilitonUI"]
        ),
        // Networking layer
        .library(
            name: "AgilitonNetworking",
            targets: ["AgilitonNetworking"]
        ),
        // Testing utilities
        .library(
            name: "AgilitonTesting",
            targets: ["AgilitonTesting"]
        )
    ],
    dependencies: [
        // Keychain - Well-established secure storage solution
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),

        // Testing - Industry standard for snapshot testing
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        // Core functionality
        .target(
            name: "AgilitonCore",
            dependencies: [
                "KeychainAccess"
            ],
            path: "Sources/AgilitonCore"
        ),

        // UI Components
        .target(
            name: "AgilitonUI",
            dependencies: ["AgilitonCore"],
            path: "Sources/AgilitonUI"
        ),

        // Networking - Using native URLSession with async/await
        .target(
            name: "AgilitonNetworking",
            dependencies: [
                "AgilitonCore"
            ],
            path: "Sources/AgilitonNetworking"
        ),

        // Testing utilities
        .target(
            name: "AgilitonTesting",
            dependencies: [
                "AgilitonCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Sources/AgilitonTesting"
        )
    ]
)