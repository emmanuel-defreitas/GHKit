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
        .testTarget(
            name: "GHKitTests",
            dependencies: ["GHKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: strictSettings
        ),
    ]
)
