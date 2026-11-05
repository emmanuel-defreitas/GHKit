import GHKitCore

extension GitHubDomain {
    /// Service information, licenses, `.gitignore` templates, codes of conduct, emojis, and Markdown rendering.
    ///
    /// The endpoints are public. Rendering Markdown with a private repository as its context needs
    /// `contents=read` on that repository, or the `repo` scope that `GitHubDomain.repositories` asks for.
    public static let meta = GitHubDomain(
        "meta",
        read: GitHubAccess(permissions: [.init("metadata", .read), .init("contents", .read)])
    )
}
