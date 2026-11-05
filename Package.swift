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
        // Everything below in one import. Pick single domains to keep the API surface and build small.
        .library(name: "GHKit", targets: ["GHKit"]),
        // Client, HTTP, authentication, pagination, GraphQL, and the models the domains share.
        .library(name: "GHKitCore", targets: ["GHKitCore"]),
        // Profiles, emails, keys, followers.
        .library(name: "GHKitUsers", targets: ["GHKitUsers"]),
        // Repositories, contents, branches, commits, releases, deployments, Pages, webhooks, rulesets.
        .library(name: "GHKitRepositories", targets: ["GHKitRepositories"]),
        // Issues, comments, labels, milestones, timelines, sub-issues, reactions.
        .library(name: "GHKitIssues", targets: ["GHKitIssues"]),
        // Pull requests, reviews, review comments, merging.
        .library(name: "GHKitPullRequests", targets: ["GHKitPullRequests"]),
        // Organizations, members, settings, and teams.
        .library(name: "GHKitOrganizations", targets: ["GHKitOrganizations"]),
        // Projects (v2): fields, items, views, status updates.
        .library(name: "GHKitProjects", targets: ["GHKitProjects"]),
        // Notifications, events, stars, and watching.
        .library(name: "GHKitActivity", targets: ["GHKitActivity"]),
        // Gists.
        .library(name: "GHKitGists", targets: ["GHKitGists"]),
        // Search code, issues, repositories, users, commits.
        .library(name: "GHKitSearch", targets: ["GHKitSearch"]),
        // GitHub App and OAuth app management.
        .library(name: "GHKitApps", targets: ["GHKitApps"]),
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
            name: "GHKitCore",
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitUsers",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitRepositories",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitIssues",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitPullRequests",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitOrganizations",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitProjects",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitActivity",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitGists",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitSearch",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitApps",
            dependencies: ["GHKitCore"],
            swiftSettings: strictSettings
        ),
        // Re-exports every domain module.
        .target(
            name: "GHKit",
            dependencies: [
                "GHKitCore", "GHKitUsers", "GHKitRepositories", "GHKitIssues", "GHKitPullRequests", "GHKitOrganizations", "GHKitProjects", "GHKitActivity",
                "GHKitGists", "GHKitSearch", "GHKitApps",
            ],
            swiftSettings: strictSettings
        ),
        .target(
            name: "GHKitUI",
            dependencies: ["GHKitCore", "GHKitUsers"],
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
            dependencies: [
                "GHKit", "GHKitCore", "GHKitUsers", "GHKitRepositories", "GHKitIssues", "GHKitPullRequests", "GHKitOrganizations", "GHKitProjects",
                "GHKitActivity", "GHKitGists", "GHKitSearch", "GHKitApps", "GHKitMCP",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            resources: [.copy("Fixtures")],
            swiftSettings: strictSettings
        ),
    ]
)
