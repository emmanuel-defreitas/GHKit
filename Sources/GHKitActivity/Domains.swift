import GHKitCore

extension GitHubDomain {
    /// Notifications, events, stars, and watching. Fine-grained tokens can't read notifications.
    public static let activity = GitHubDomain(
        "activity",
        read: GitHubAccess(scopes: [.notifications, .readUser], permissions: [.init("starring", .read)]),
        write: GitHubAccess(scopes: [.publicRepo], permissions: [.init("starring", .write)])
    )
}
