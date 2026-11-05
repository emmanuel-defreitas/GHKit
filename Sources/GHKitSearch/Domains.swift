import GHKitCore

extension GitHubDomain {
    /// Search across GitHub. Results include private resources the credential can read.
    public static let search = GitHubDomain(
        "search",
        read: GitHubAccess(
            scopes: [.repo], permissions: [.init("metadata", .read), .init("contents", .read), .init("issues", .read), .init("pull_requests", .read)])
    )
}
