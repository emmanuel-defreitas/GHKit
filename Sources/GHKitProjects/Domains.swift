import GHKitCore

extension GitHubDomain {
    /// Projects, their fields, items, views, and status updates.
    public static let projects = GitHubDomain(
        "projects",
        read: GitHubAccess(scopes: [.readProject, .readOrg], permissions: [.init("organization_projects", .read)]),
        write: GitHubAccess(scopes: [.project], permissions: [.init("organization_projects", .write)])
    )
}
