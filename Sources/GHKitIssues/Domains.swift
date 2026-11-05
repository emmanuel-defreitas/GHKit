import GHKitCore

extension GitHubDomain {
    /// Issues, their comments, labels, milestones, timelines, and sub-issues.
    public static let issues = GitHubDomain(
        "issues",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("issues", .read)]),
        write: GitHubAccess(permissions: [.init("issues", .write)])
    )

    /// Emoji reactions.
    public static let reactions = GitHubDomain(
        "reactions",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("issues", .read)]),
        write: GitHubAccess(permissions: [.init("issues", .write), .init("pull_requests", .write)])
    )
}
