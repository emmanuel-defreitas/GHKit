import GHKitCore

extension GitHubDomain {
    /// Service information, licenses, `.gitignore` templates, codes of conduct, emojis, and Markdown rendering.
    /// These endpoints are public and need no scope or permission.
    public static let meta = GitHubDomain(
        "meta"
    )
}
