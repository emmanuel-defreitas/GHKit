import GHKitCore

extension GitHubDomain {
    /// Gists and their comments. Public gists need no scope; secret gists and changes need `gist`.
    public static let gists = GitHubDomain(
        "gists",
        write: GitHubAccess(scopes: [.gist])
    )
}
