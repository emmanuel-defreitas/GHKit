import Foundation
import GHKitCore

extension GitHubClient {
    /// Organization endpoints.
    public var organizations: OrganizationsAPI { OrganizationsAPI(client: scoped(to: .organizations)) }
}

/// Organization endpoints. Reach them with `github.organizations`.
///
/// `org` is always the organization's login, such as `"github"`.
///
/// Part of the `GHKitOrganizations` library.
public struct OrganizationsAPI: Sendable {
    let client: GitHubClient

    func path(_ org: String, _ rest: String = "") -> String { "/orgs/\(escape(org))\(rest)" }

    // MARK: Organizations

    /// Every organization, in creation order. `GET /organizations`
    /// - Parameter since: Only organizations with an ID greater than this.
    public func all(since: Int? = nil, perPage: Int = 100) -> Paginated<SimpleOrganization> {
        client.paginate(GitHubRequest(.get, "/organizations", query: .query(("since", since), ("per_page", perPage))))
    }

    /// Organizations the signed-in user belongs to. `GET /user/orgs`
    public func list(perPage: Int = 100) -> Paginated<SimpleOrganization> {
        client.paginate(GitHubRequest(.get, "/user/orgs", query: .query(("per_page", perPage))))
    }

    /// A user's public organization memberships. `GET /users/{username}/orgs`
    public func list(of login: String, perPage: Int = 100) -> Paginated<SimpleOrganization> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/orgs", query: .query(("per_page", perPage))))
    }

    /// An organization's profile. `GET /orgs/{org}`
    public func organization(_ org: String) async throws(GitHubError) -> Organization {
        try await client.value(GitHubRequest(.get, path(org)))
    }

    /// Updates an organization's profile and settings. `PATCH /orgs/{org}`
    @discardableResult
    public func update(_ org: String, _ changes: OrganizationUpdate) async throws(GitHubError) -> Organization {
        try await client.value(GitHubRequest(.patch, path(org), body: changes))
    }

    /// Deletes an organization and all its repositories. The name is unusable for 90 days. `DELETE /orgs/{org}`
    public func delete(_ org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org)))
    }

    /// GitHub App installations on an organization. `GET /orgs/{org}/installations`
    public func installations(of org: String, perPage: Int = 100) -> Paginated<Installation> {
        client.paginate(.wrappedList(path(org, "/installations"), key: "installations", query: .query(("per_page", perPage))))
    }

    // MARK: Members

    /// An organization's members. Concealed members appear only to other members. `GET /orgs/{org}/members`
    public func members(
        of org: String, filter: MemberFilter = .all, role: MemberRoleFilter = .all, perPage: Int = 100
    ) -> Paginated<SimpleUser> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/members"), query: .query(("filter", filter), ("role", role), ("per_page", perPage))))
    }

    /// Whether `login` is a member, publicly or privately. `GET /orgs/{org}/members/{username}`
    public func isMember(_ login: String, of org: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(org, "/members/\(escape(login))"))
    }

    /// Removes a member from the organization and all its teams. `DELETE /orgs/{org}/members/{username}`
    public func removeMember(_ login: String, from org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/members/\(escape(login))")))
    }

    /// A user's membership, including pending invitations. `GET /orgs/{org}/memberships/{username}`
    public func membership(of login: String, in org: String) async throws(GitHubError) -> OrganizationMembership {
        try await client.value(GitHubRequest(.get, path(org, "/memberships/\(escape(login))")))
    }

    /// Adds a member or changes their role. New members get an invitation first. `PUT /orgs/{org}/memberships/{username}`
    /// - Parameter role: `.admin` or `.member`.
    @discardableResult
    public func setMembership(
        of login: String, in org: String, role: OrganizationRole = .member
    ) async throws(GitHubError) -> OrganizationMembership {
        struct Body: Encodable, Sendable { let role: OrganizationRole }
        return try await client.value(
            GitHubRequest(.put, path(org, "/memberships/\(escape(login))"), body: Body(role: role)))
    }

    /// Removes a membership, or cancels a pending invitation. `DELETE /orgs/{org}/memberships/{username}`
    public func removeMembership(of login: String, from org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/memberships/\(escape(login))")))
    }

    // MARK: Public members

    /// Members who show their membership publicly. `GET /orgs/{org}/public_members`
    public func publicMembers(of org: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, path(org, "/public_members"), query: .query(("per_page", perPage))))
    }

    /// Whether `login` shows their membership publicly. `GET /orgs/{org}/public_members/{username}`
    public func isPublicMember(_ login: String, of org: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(org, "/public_members/\(escape(login))"))
    }

    /// Shows the signed-in user's membership publicly. `PUT /orgs/{org}/public_members/{username}`
    /// - Parameter login: The signed-in user's login. You can only change your own visibility.
    public func publicizeMembership(of login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/public_members/\(escape(login))")))
    }

    /// Hides the signed-in user's membership. `DELETE /orgs/{org}/public_members/{username}`
    /// - Parameter login: The signed-in user's login. You can only change your own visibility.
    public func concealMembership(of login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/public_members/\(escape(login))")))
    }

    // MARK: Outside collaborators

    /// People with access to some repositories who aren't members. `GET /orgs/{org}/outside_collaborators`
    public func outsideCollaborators(
        of org: String, filter: MemberFilter = .all, perPage: Int = 100
    ) -> Paginated<SimpleUser> {
        client.paginate(
            GitHubRequest(.get, path(org, "/outside_collaborators"), query: .query(("filter", filter), ("per_page", perPage))))
    }

    /// Turns a member into an outside collaborator. `PUT /orgs/{org}/outside_collaborators/{username}`
    /// - Parameter async: Lets GitHub finish the conversion in the background, for members with lots of access.
    public func convertToOutsideCollaborator(_ login: String, in org: String, async: Bool = false) async throws(GitHubError) {
        struct Body: Encodable, Sendable { let async: Bool }
        try await client.value(
            GitHubRequest<Void>(.put, path(org, "/outside_collaborators/\(escape(login))"), body: Body(async: async)))
    }

    /// Removes an outside collaborator from every repository. `DELETE /orgs/{org}/outside_collaborators/{username}`
    public func removeOutsideCollaborator(_ login: String, from org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/outside_collaborators/\(escape(login))")))
    }

    // MARK: Invitations

    /// Invitations waiting for a response. `GET /orgs/{org}/invitations`
    public func invitations(
        of org: String, role: InvitationRoleFilter = .all, source: InvitationSourceFilter = .all, perPage: Int = 100
    ) -> Paginated<OrganizationInvitation> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/invitations"),
                query: .query(("role", role), ("invitation_source", source), ("per_page", perPage))))
    }

    /// Invitations that failed or expired. `GET /orgs/{org}/failed_invitations`
    public func failedInvitations(of org: String, perPage: Int = 100) -> Paginated<OrganizationInvitation> {
        client.paginate(GitHubRequest(.get, path(org, "/failed_invitations"), query: .query(("per_page", perPage))))
    }

    /// Invites someone by user ID or email. `POST /orgs/{org}/invitations`
    @discardableResult
    public func invite(_ invitation: NewOrganizationInvitation, to org: String) async throws(GitHubError) -> OrganizationInvitation {
        try await client.value(GitHubRequest(.post, path(org, "/invitations"), body: invitation))
    }

    /// Cancels a pending invitation. `DELETE /orgs/{org}/invitations/{invitation_id}`
    public func cancelInvitation(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/invitations/\(id)")))
    }

    /// Teams the invitee will join. `GET /orgs/{org}/invitations/{invitation_id}/teams`
    public func invitationTeams(id: Int, in org: String, perPage: Int = 100) -> Paginated<Team> {
        client.paginate(GitHubRequest(.get, path(org, "/invitations/\(id)/teams"), query: .query(("per_page", perPage))))
    }

    // MARK: Blocking

    /// Users the organization has blocked. `GET /orgs/{org}/blocks`
    public func blockedUsers(in org: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, path(org, "/blocks"), query: .query(("per_page", perPage))))
    }

    /// Whether the organization has blocked `login`. `GET /orgs/{org}/blocks/{username}`
    public func isBlocked(_ login: String, in org: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(org, "/blocks/\(escape(login))"))
    }

    /// Blocks a user from the organization's repositories. `PUT /orgs/{org}/blocks/{username}`
    public func block(_ login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/blocks/\(escape(login))")))
    }

    /// Unblocks a user. `DELETE /orgs/{org}/blocks/{username}`
    public func unblock(_ login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/blocks/\(escape(login))")))
    }

    // MARK: Your memberships

    /// The signed-in user's organization memberships. `GET /user/memberships/orgs`
    /// - Parameter state: Pass `.pending` to list invitations waiting for you.
    public func memberships(state: MembershipState? = nil, perPage: Int = 100) -> Paginated<OrganizationMembership> {
        client.paginate(
            GitHubRequest(.get, "/user/memberships/orgs", query: .query(("state", state), ("per_page", perPage))))
    }

    /// The signed-in user's membership in one organization. `GET /user/memberships/orgs/{org}`
    public func membership(in org: String) async throws(GitHubError) -> OrganizationMembership {
        try await client.value(GitHubRequest(.get, "/user/memberships/orgs/\(escape(org))"))
    }

    /// Accepts the signed-in user's pending invitation. `PATCH /user/memberships/orgs/{org}`
    @discardableResult
    public func acceptInvitation(to org: String) async throws(GitHubError) -> OrganizationMembership {
        struct Body: Encodable, Sendable { let state = "active" }
        return try await client.value(GitHubRequest(.patch, "/user/memberships/orgs/\(escape(org))", body: Body()))
    }
}
