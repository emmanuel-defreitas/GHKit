// swift-tools-version: 6.2
// Swift 6.2 is the minimum because GHKit uses `@concurrent`, nonisolated(nonsending)
// by default, and default MainActor isolation for the SwiftUI module.

import PackageDescription

let strictSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "GHKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        // Core client: networking, auth, and the typed GitHub API surface.
        .library(name: "GHKit", targets: ["GHKit"]),
        // SwiftUI helpers: an observable session, sign-in views, environment values.
        .library(name: "GHKitUI", targets: ["GHKitUI"]),
        // Model Context Protocol tools that expose the GitHub API to AI assistants.
        .library(name: "GHKitMCP", targets: ["GHKitMCP"]),
    ],
    dependencies: [
        // Only GHKitMCP uses it, so apps that link GHKit or GHKitUI alone never fetch it.
        // Pinned to a minor version: before 1.0, a minor release of the SDK may break its API.
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMinor(from: "0.12.1"))
    ],
    targets: [
        .target(
            name: "GHKit",
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitUI",
            dependencies: ["GHKit"],
            swiftSettings: strictSettings + [.defaultIsolation(MainActor.self)]
        ),
        .target(
            name: "GHKitMCP",
            dependencies: ["GHKit", .product(name: "MCP", package: "swift-sdk")],
            swiftSettings: strictSettings
        ),
        // A stdio MCP server for trying the tools from an MCP client. Not a product.
        .executableTarget(
            name: "ghkit-mcp",
            dependencies: ["GHKit", "GHKitMCP", .product(name: "MCP", package: "swift-sdk")],
            swiftSettings: strictSettings
        ),
        .testTarget(
            name: "GHKitTests",
            dependencies: ["GHKit", "GHKitMCP", .product(name: "MCP", package: "swift-sdk")],
            resources: [.copy("Fixtures")],
            swiftSettings: strictSettings
        ),
    ]
)
