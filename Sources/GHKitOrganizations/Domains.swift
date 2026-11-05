import GHKitCore

extension GitHubDomain {
    /// Organizations, their members, settings, and invitations.
    public static let organizations = GitHubDomain(
        "organizations",
        read: GitHubAccess(scopes: [.readOrg], permissions: [.init("members", .read), .init("organization_administration", .read)]),
        write: GitHubAccess(
            scopes: [.adminOrg, .adminOrgHook],
            permissions: [.init("members", .write), .init("organization_administration", .write), .init("organization_hooks", .write)])
    )

    /// Teams, their members, and their repository access.
    public static let teams = GitHubDomain(
        "teams",
        read: GitHubAccess(scopes: [.readOrg], permissions: [.init("members", .read)]),
        write: GitHubAccess(scopes: [.adminOrg], permissions: [.init("members", .write)])
    )
}
