import GHKitCore

extension GitHubDomain {
    /// GitHub Actions workflows, workflow runs, jobs, and artifacts.
    ///
    /// Changing workflow files is a contents write that also needs the `workflow` scope or the `workflows`
    /// permission; these endpoints only run and manage workflows.
    public static let actions = GitHubDomain(
        "actions",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("actions", .read)]),
        write: GitHubAccess(permissions: [.init("actions", .write)])
    )
}
