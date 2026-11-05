import GHKitCore

extension GitHubDomain {
    /// Repositories and their contents, branches, commits, releases, deployments, Pages, and webhooks.
    public static let repositories = GitHubDomain(
        "repositories",
        read: GitHubAccess(scopes: [.repo], permissions: [.init("metadata", .read), .init("contents", .read), .init("deployments", .read)]),
        write: GitHubAccess(permissions: [
            .init("contents", .write), .init("administration", .write), .init("deployments", .write), .init("environments", .write), .init("pages", .write),
            .init("repository_hooks", .write), .init("statuses", .write),
        ])
    )

    /// Repository and organization rulesets.
    public static let rulesets = GitHubDomain(
        "rulesets",
        read: GitHubAccess(scopes: [.repo, .readOrg], permissions: [.init("metadata", .read), .init("organization_administration", .read)]),
        write: GitHubAccess(scopes: [.adminOrg], permissions: [.init("administration", .write), .init("organization_administration", .write)])
    )
}
