import GHKitCore

extension GitHubDomain {
    /// GitHub App and OAuth app management. These endpoints sign with an app JWT, an installation token, or the app's client secret, not token scopes.
    public static let apps = GitHubDomain(
        "apps"
    )
}
