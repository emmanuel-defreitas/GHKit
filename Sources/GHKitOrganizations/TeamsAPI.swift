import Foundation
import GHKitCore

extension GitHubClient {
    /// Team endpoints.
    public var teams: TeamsAPI { TeamsAPI(client: self) }
}

/// Team endpoints. Reach them with `github.teams`.
///
/// Teams are named by their slug, such as `"justice-league"`, within an organization login.
///
/// Part of the `GHKitOrganizations` library.
public struct TeamsAPI: Sendable {
    let client: GitHubClient

    private func path(_ team: String, _ org: String, _ rest: String = "") -> String {
        "/orgs/\(escape(org))/teams/\(escape(team))\(rest)"
    }

    // MARK: Teams

    /// Teams visible to the signed-in user in an organization. `GET /orgs/{org}/teams`
    public func list(in org: String, type: TeamTypeFilter = .all, perPage: Int = 100) -> Paginated<Team> {
        client.paginate(
            GitHubRequest(.get, "/orgs/\(escape(org))/teams", query: .query(("team_type", type), ("per_page", perPage))))
    }

    /// Teams the signed-in user belongs to, across organizations. `GET /user/teams`
    public func mine(perPage: Int = 100) -> Paginated<Team> {
        client.paginate(GitHubRequest(.get, "/user/teams", query: .query(("per_page", perPage))))
    }

    /// One team. `GET /orgs/{org}/teams/{team_slug}`
    public func team(_ team: String, in org: String) async throws(GitHubError) -> Team {
        try await client.value(GitHubRequest(.get, path(team, org)))
    }

    /// Creates a team. The signed-in user becomes a maintainer. `POST /orgs/{org}/teams`
    @discardableResult
    public func create(_ team: NewTeam, in org: String) async throws(GitHubError) -> Team {
        try await client.value(GitHubRequest(.post, "/orgs/\(escape(org))/teams", body: team))
    }

    /// Changes a team's name, description, visibility, or parent. `PATCH /orgs/{org}/teams/{team_slug}`
    @discardableResult
    public func update(_ team: String, in org: String, _ changes: TeamUpdate) async throws(GitHubError) -> Team {
        try await client.value(GitHubRequest(.patch, path(team, org), body: changes))
    }

    /// Deletes a team and all its child teams. `DELETE /orgs/{org}/teams/{team_slug}`
    public func delete(_ team: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(team, org)))
    }

    /// Teams nested directly under a team. `GET /orgs/{org}/teams/{team_slug}/teams`
    public func childTeams(of team: String, in org: String, perPage: Int = 100) -> Paginated<Team> {
        client.paginate(GitHubRequest(.get, path(team, org, "/teams"), query: .query(("per_page", perPage))))
    }

    // MARK: Members

    /// A team's members, including members of child teams. `GET /orgs/{org}/teams/{team_slug}/members`
    public func members(
        of team: String, in org: String, role: TeamRoleFilter = .all, perPage: Int = 100
    ) -> Paginated<TeamMember> {
        client.paginate(GitHubRequest(.get, path(team, org, "/members"), query: .query(("role", role), ("per_page", perPage))))
    }

    /// Someone's role on a team. `GET /orgs/{org}/teams/{team_slug}/memberships/{username}`
    public func membership(of login: String, on team: String, in org: String) async throws(GitHubError) -> TeamMembership {
        try await client.value(GitHubRequest(.get, path(team, org, "/memberships/\(escape(login))")))
    }

    /// Adds someone to a team, or changes their role. People outside the organization get invited.
    /// `PUT /orgs/{org}/teams/{team_slug}/memberships/{username}`
    @discardableResult
    public func setMembership(
        of login: String, on team: String, in org: String, role: TeamRole = .member
    ) async throws(GitHubError) -> TeamMembership {
        struct Body: Encodable, Sendable { let role: TeamRole }
        return try await client.value(
            GitHubRequest(.put, path(team, org, "/memberships/\(escape(login))"), body: Body(role: role)))
    }

    /// Removes someone from a team. `DELETE /orgs/{org}/teams/{team_slug}/memberships/{username}`
    public func removeMembership(of login: String, from team: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(team, org, "/memberships/\(escape(login))")))
    }

    /// Organization invitations that will add people to this team. `GET /orgs/{org}/teams/{team_slug}/invitations`
    public func invitations(for team: String, in org: String, perPage: Int = 100) -> Paginated<OrganizationInvitation> {
        client.paginate(GitHubRequest(.get, path(team, org, "/invitations"), query: .query(("per_page", perPage))))
    }

    // MARK: Repositories

    /// Repositories a team can access. `GET /orgs/{org}/teams/{team_slug}/repos`
    public func repositories(of team: String, in org: String, perPage: Int = 100) -> Paginated<Repository> {
        client.paginate(GitHubRequest(.get, path(team, org, "/repos"), query: .query(("per_page", perPage))))
    }

    /// The team's access to a repository, or `nil` if it has none. Includes access from parent teams.
    /// `GET /orgs/{org}/teams/{team_slug}/repos/{owner}/{repo}`
    ///
    /// The repository's `permissions` and `roleName` describe the team's access.
    public func repository(
        _ owner: String, _ repository: String, for team: String, in org: String
    ) async throws(GitHubError) -> Repository? {
        var request = GitHubRequest<Repository>(.get, path(team, org, "/repos/\(escape(owner))/\(escape(repository))"))
        request.headers["Accept"] = "application/vnd.github.v3.repository+json"
        do {
            return try await client.value(request)
        } catch .notFound(_, _) {
            return nil
        }
    }

    /// Gives a team access to a repository, or changes its role. `PUT /orgs/{org}/teams/{team_slug}/repos/{owner}/{repo}`
    public func setRepositoryRole(
        _ role: RepositoryRole, on owner: String, _ repository: String, for team: String, in org: String
    ) async throws(GitHubError) {
        struct Body: Encodable, Sendable { let permission: RepositoryRole }
        try await client.value(
            GitHubRequest<Void>(
                .put, path(team, org, "/repos/\(escape(owner))/\(escape(repository))"), body: Body(permission: role)))
    }

    /// Takes a repository away from a team. Members keep any access they have another way.
    /// `DELETE /orgs/{org}/teams/{team_slug}/repos/{owner}/{repo}`
    public func removeRepository(_ owner: String, _ repository: String, from team: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(team, org, "/repos/\(escape(owner))/\(escape(repository))")))
    }
}
