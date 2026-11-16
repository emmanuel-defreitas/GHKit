import GHKitCore

extension GitHubDomain {
    /// Check runs and check suites.
    ///
    /// Only GitHub Apps can create and update check runs and suites; people and OAuth apps can read them
    /// and ask for them to run again.
    public static let checks = GitHubDomain(
        "checks",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("checks", .read)]),
        write: GitHubAccess(permissions: [.init("checks", .write)])
    )
}
