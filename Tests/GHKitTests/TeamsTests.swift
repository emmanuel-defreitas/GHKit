import Foundation
import Testing

@testable import GHKit

@Suite("Teams")
struct TeamsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func teamModelsDecode() throws {
        let team = try decoder.decode(Team.self, from: loadFixture("team-full"))
        #expect(team.slug == "justice-league")
        #expect(team.membersCount == 3)
        #expect(team.organization?.login == "github")
        #expect(team.createdAt != nil)
        _ = try decoder.decode([Team].self, from: loadFixture("team-full-items"))

        let members = try decoder.decode([TeamMember].self, from: loadFixture("team-member-items"))
        #expect(members.first?.user.login == "octocat")
        #expect(members.first?.role == .member)
        #expect(members.first?.inherited == false)

        let membership = try decoder.decode(TeamMembership.self, from: loadFixture("team-membership"))
        #expect(membership.role == .maintainer)
        #expect(membership.state == .active)

        let repository = try decoder.decode(MinimalRepository.self, from: loadFixture("team-repository"))
        #expect(repository.permissions?.admin == false)
        #expect(repository.permissions?.pull == true)
    }

    // MARK: Requests

    @Test func createAndUpdate() async throws {
        let transport = MockTransport(.fixture("team-full", status: 201))
        let teams = makeClient(transport).teams
        _ = try await teams.create(
            NewTeam(name: "Core", maintainers: ["mona"], privacy: .closed, parentTeamID: 3), in: "acme")
        _ = try await teams.update("core", in: "acme", TeamUpdate(description: "Core team", parent: .topLevel))
        _ = try await teams.update("core", in: "acme", TeamUpdate(parent: .team(id: 4)))
        #expect(transport.requests[0].path == "/orgs/acme/teams")
        #expect(
            transport.requests[0].jsonBody == ["name": "Core", "maintainers": ["mona"], "privacy": "closed", "parent_team_id": 3])
        #expect(transport.requests[1].httpMethod == "PATCH")
        #expect(transport.requests[1].path == "/orgs/acme/teams/core")
        #expect(transport.requests[1].jsonBody == ["description": "Core team", "parent_team_id": nil])
        #expect(transport.requests[2].jsonBody == ["parent_team_id": 4])
    }

    @Test func lists() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/orgs/acme/teams/core/members": .fixture("team-member-items")
            case "/orgs/acme/teams/core/repos": .fixture("minimal-repository-items")
            case "/orgs/acme/teams/core/invitations": .fixture("organization-invitation-items")
            case "/user/teams": .fixture("team-full-items")
            default: .fixture("team-items")
            }
        }
        let teams = makeClient(transport).teams
        _ = try await teams.list(in: "acme", type: .enterprise).collect()
        _ = try await teams.mine().collect()
        _ = try await teams.childTeams(of: "core", in: "acme").collect()
        _ = try await teams.members(of: "core", in: "acme", role: .maintainer).collect()
        _ = try await teams.invitations(for: "core", in: "acme").collect()
        _ = try await teams.repositories(of: "core", in: "acme").collect()
        #expect(
            transport.requests.map(\.path) == [
                "/orgs/acme/teams", "/user/teams", "/orgs/acme/teams/core/teams", "/orgs/acme/teams/core/members",
                "/orgs/acme/teams/core/invitations", "/orgs/acme/teams/core/repos",
            ])
        #expect(transport.requests[0].queryItems == ["team_type": "enterprise", "per_page": "100"])
        #expect(transport.requests[3].queryItems == ["role": "maintainer", "per_page": "100"])
    }

    @Test func memberships() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("team-membership")
        }
        let teams = makeClient(transport).teams
        _ = try await teams.membership(of: "mona", on: "core", in: "acme")
        _ = try await teams.setMembership(of: "mona", on: "core", in: "acme", role: .maintainer)
        try await teams.removeMembership(of: "mona", from: "core", in: "acme")
        try await teams.delete("core", in: "acme")
        #expect(transport.requests[1].jsonBody == ["role": "maintainer"])
        #expect(
            transport.requests.map { "\($0.httpMethod!) \($0.path)" } == [
                "GET /orgs/acme/teams/core/memberships/mona", "PUT /orgs/acme/teams/core/memberships/mona",
                "DELETE /orgs/acme/teams/core/memberships/mona", "DELETE /orgs/acme/teams/core",
            ])
    }

    @Test(arguments: [true, false])
    func repositoryAccessReturnsNilWithoutAccess(hasAccess: Bool) async throws {
        let transport = MockTransport(hasAccess ? .fixture("team-repository") : .json(#"{"message":"Not Found"}"#, status: 404))
        let repository = try await makeClient(transport).teams.repository("octocat", "Hello-World", for: "core", in: "acme")
        #expect((repository != nil) == hasAccess)
        let request = try #require(transport.requests.first)
        #expect(request.path == "/orgs/acme/teams/core/repos/octocat/Hello-World")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.v3.repository+json")
    }

    @Test func repositoryRoles() async throws {
        let transport = MockTransport(.noContent())
        let teams = makeClient(transport).teams
        try await teams.setRepositoryRole(.maintain, on: "octocat", "Hello-World", for: "core", in: "acme")
        try await teams.removeRepository("octocat", "Hello-World", from: "core", in: "acme")
        #expect(transport.requests[0].httpMethod == "PUT")
        #expect(transport.requests[0].jsonBody == ["permission": "maintain"])
        #expect(transport.requests[1].httpMethod == "DELETE")
        #expect(transport.requests[1].path == "/orgs/acme/teams/core/repos/octocat/Hello-World")
    }
}
