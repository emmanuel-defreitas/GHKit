import GHKitCore

extension GitHubDomain {
    /// Pull requests, reviews, review comments, and merging.
    public static let pullRequests = GitHubDomain(
        "pull_requests",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("pull_requests", .read), .init("contents", .read)]),
        write: GitHubAccess(permissions: [.init("pull_requests", .write), .init("contents", .write)])
    )
}
