import Foundation
import MCP
import Testing

@testable import GHKit
@testable import GHKitMCP

@Suite("MCP user, organization, team, and project tools")
struct OrganizationToolsTests {
    static let team: [String: MCP.Value] = ["org": "acme", "team": "ios"]
    static let teamBase = "/orgs/acme/teams/ios"
    static let project: [String: MCP.Value] = ["org": "acme", "project": 2]
    static let projectBase = "/orgs/acme/projectsV2/2"

    static func with(_ base: [String: MCP.Value], _ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        base.merging(extra) { _, new in new }
    }

    static let cases: [ToolRequestCase] = [
        // Users
        .init(tool: "get_user", arguments: ["login": "octocat"], response: .fixture("private-user"), route: "GET /users/octocat"),
        .init(tool: "get_user", arguments: ["id": 583231], response: .fixture("private-user"), route: "GET /user/583231"),
        .init(
            tool: "list_followers", arguments: ["user": "octocat"], response: .fixture("simple-user-items"),
            route: "GET /users/octocat/followers", query: ["per_page": "30"]),
        .init(
            tool: "list_following", arguments: [:], response: .fixture("simple-user-items"), route: "GET /user/following",
            query: ["per_page": "30"]),
        .init(
            tool: "update_profile", arguments: ["bio": "Hi", "hireable": true], response: .fixture("private-user"), route: "PATCH /user",
            body: ["bio": "Hi", "hireable": true]),
        .init(tool: "follow_user", arguments: ["user": "octocat"], response: .noContent(), route: "PUT /user/following/octocat"),
        .init(tool: "unfollow_user", arguments: ["user": "octocat"], response: .noContent(), route: "DELETE /user/following/octocat"),
        // Organizations
        .init(
            tool: "list_organizations", arguments: [:], response: .fixture("organization-simple-items"), route: "GET /user/orgs",
            query: ["per_page": "30"]),
        .init(tool: "get_organization", arguments: ["org": "acme"], response: .fixture("organization-full"), route: "GET /orgs/acme"),
        .init(
            tool: "list_organization_members", arguments: ["org": "acme", "role": "admin", "filter": "2fa_disabled"],
            response: .fixture("simple-user-items"), route: "GET /orgs/acme/members",
            query: ["role": "admin", "filter": "2fa_disabled", "per_page": "30"]),
        .init(
            tool: "get_organization_membership", arguments: ["org": "acme", "user": "octocat"], response: .fixture("org-membership"),
            route: "GET /orgs/acme/memberships/octocat"),
        .init(
            tool: "get_organization_membership", arguments: ["org": "acme"], response: .fixture("org-membership"),
            route: "GET /user/memberships/orgs/acme"),
        .init(
            tool: "list_outside_collaborators", arguments: ["org": "acme"], response: .fixture("simple-user-items"),
            route: "GET /orgs/acme/outside_collaborators", query: ["filter": "all", "per_page": "30"]),
        .init(
            tool: "list_organization_invitations", arguments: ["org": "acme", "failed": true],
            response: .fixture("organization-invitation-items"), route: "GET /orgs/acme/failed_invitations", query: ["per_page": "30"]),
        .init(
            tool: "update_organization", arguments: ["org": "acme", "description": "Rockets"], response: .fixture("organization-full"),
            route: "PATCH /orgs/acme", body: ["description": "Rockets"]),
        .init(
            tool: "set_organization_membership", arguments: ["org": "acme", "user": "octocat", "role": "admin"],
            response: .fixture("org-membership"), route: "PUT /orgs/acme/memberships/octocat", body: ["role": "admin"]),
        .init(
            tool: "remove_organization_member", arguments: ["org": "acme", "user": "octocat"], response: .noContent(),
            route: "DELETE /orgs/acme/memberships/octocat"),
        .init(
            tool: "invite_to_organization", arguments: ["org": "acme", "email": "a@example.com", "teamIDs": [12, "13"]],
            response: .fixture("organization-invitation", status: 201), route: "POST /orgs/acme/invitations",
            body: ["email": "a@example.com", "role": "direct_member", "team_ids": [12, 13]]),
        .init(
            tool: "cancel_organization_invitation", arguments: ["org": "acme", "invitationID": 7], response: .noContent(),
            route: "DELETE /orgs/acme/invitations/7"),
        .init(
            tool: "accept_organization_invitation", arguments: ["org": "acme"], response: .fixture("org-membership"),
            route: "PATCH /user/memberships/orgs/acme", body: ["state": "active"]),
        // Teams
        .init(tool: "list_teams", arguments: [:], response: .fixture("team-full-items"), route: "GET /user/teams", query: ["per_page": "30"]),
        .init(
            tool: "list_teams", arguments: ["org": "acme"], response: .fixture("team-items"), route: "GET /orgs/acme/teams",
            query: ["team_type": "all", "per_page": "30"]),
        .init(tool: "get_team", arguments: team, response: .fixture("team-full"), route: "GET \(teamBase)"),
        .init(
            tool: "list_team_members", arguments: with(team, ["role": "maintainer"]), response: .fixture("team-member-items"),
            route: "GET \(teamBase)/members", query: ["role": "maintainer", "per_page": "30"]),
        .init(
            tool: "get_team_membership", arguments: with(team, ["user": "octocat"]), response: .fixture("team-membership"),
            route: "GET \(teamBase)/memberships/octocat"),
        .init(
            tool: "list_child_teams", arguments: team, response: .fixture("team-items"), route: "GET \(teamBase)/teams",
            query: ["per_page": "30"]),
        .init(
            tool: "list_team_repositories", arguments: team, response: .fixture("minimal-repository-items"), route: "GET \(teamBase)/repos",
            query: ["per_page": "30"]),
        .init(
            tool: "create_team",
            arguments: ["org": "acme", "name": "iOS", "privacy": "closed", "repositories": ["acme/app"], "parentTeamID": 3],
            response: .fixture("team-full", status: 201), route: "POST /orgs/acme/teams",
            body: ["name": "iOS", "privacy": "closed", "repo_names": ["acme/app"], "parent_team_id": 3]),
        .init(
            tool: "update_team", arguments: with(team, ["description": "Apps", "topLevel": true]), response: .fixture("team-full"),
            route: "PATCH \(teamBase)", body: ["description": "Apps", "parent_team_id": nil]),
        .init(tool: "delete_team", arguments: team, response: .noContent(), route: "DELETE \(teamBase)"),
        .init(
            tool: "set_team_membership", arguments: with(team, ["user": "octocat", "role": "maintainer"]),
            response: .fixture("team-membership"), route: "PUT \(teamBase)/memberships/octocat", body: ["role": "maintainer"]),
        .init(
            tool: "remove_team_membership", arguments: with(team, ["user": "octocat"]), response: .noContent(),
            route: "DELETE \(teamBase)/memberships/octocat"),
        .init(
            tool: "set_team_repository_role", arguments: with(team, ["owner": "acme", "repo": "app", "role": "push"]),
            response: .noContent(), route: "PUT \(teamBase)/repos/acme/app", body: ["permission": "push"]),
        .init(
            tool: "remove_team_repository", arguments: with(team, ["owner": "acme", "repo": "app"]), response: .noContent(),
            route: "DELETE \(teamBase)/repos/acme/app"),
        // Projects over REST
        .init(
            tool: "list_projects", arguments: ["user": "octocat", "query": "is:open"], response: .fixtureList("projects-v2"),
            route: "GET /users/octocat/projectsV2", query: ["q": "is:open", "per_page": "30"]),
        .init(tool: "get_project", arguments: project, response: .fixture("projects-v2"), route: "GET \(projectBase)"),
        .init(
            tool: "list_project_fields", arguments: project, response: .fixtureList("projects-v2-field-text"),
            route: "GET \(projectBase)/fields", query: ["per_page": "30"]),
        .init(
            tool: "list_project_items", arguments: with(project, ["fields": [1, 2], "query": "is:open"]),
            response: .fixtureList("projects-v2-item-simple"), route: "GET \(projectBase)/items",
            query: ["q": "is:open", "fields": "1,2", "per_page": "30"]),
        .init(
            tool: "get_project_item", arguments: with(project, ["itemID": 17]), response: .fixture("projects-v2-item-simple"),
            route: "GET \(projectBase)/items/17"),
        .init(
            tool: "add_project_item", arguments: with(project, ["type": "pull_request", "owner": "acme", "repo": "app", "number": 6]),
            response: .fixture("projects-v2-item-simple", status: 201), route: "POST \(projectBase)/items",
            body: ["type": "PullRequest", "owner": "acme", "repo": "app", "number": 6]),
        .init(
            tool: "add_project_draft_issue", arguments: with(project, ["title": "Plan"]),
            response: .fixture("projects-v2-item-simple", status: 201), route: "POST \(projectBase)/drafts", body: ["title": "Plan"]),
        .init(
            tool: "update_project_item", arguments: with(project, ["itemID": 17, "fieldID": 4, "optionID": "opt"]),
            response: .fixture("projects-v2-item-simple"), route: "PATCH \(projectBase)/items/17",
            body: ["fields": [["id": 4, "value": "opt"]]]),
        .init(
            tool: "delete_project_item", arguments: with(project, ["itemID": 17]), response: .noContent(),
            route: "DELETE \(projectBase)/items/17"),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    /// Tools that go through GraphQL send several requests, so they're checked separately below.
    static let graphQLTools = [
        "create_project", "update_project", "delete_project", "list_project_status_updates", "create_project_status_update",
    ]

    @Test func coversEveryTool() {
        let tools = [UserTools.tools, OrganizationTools.tools, TeamTools.tools, ProjectTools.tools]
            .flatMap { $0(.readWrite) }.map(\.name)
        let untested = Set(tools).subtracting(Self.cases.map(\.tool)).subtracting(Self.graphQLTools)
        #expect(untested.isEmpty, "Untested: \(untested.sorted())")
    }

    // MARK: GraphQL project management

    /// A transport that answers GraphQL with `data` and everything else with the project fixture.
    static func projectTransport(_ data: String) -> MockTransport {
        let project = String(decoding: loadFixture("projects-v2"), as: UTF8.self)
        let org = #"{"login":"acme","id":9,"node_id":"O_acme","type":"Organization"}"#
        return MockTransport { request, _ in
            switch request.path {
            case "/graphql": .json(#"{"data":\#(data)}"#)
            case "/users/acme": .json(org)
            default: .json(project)
            }
        }
    }

    @Test func createProjectResolvesTheOwner() async throws {
        let transport = Self.projectTransport(#"{"result":{"projectV2":{"number":2}}}"#)
        let (text, isError) = try await callTool("create_project", ["org": "acme", "title": "Roadmap"], on: transport)
        #expect(!isError, "\(text)")
        #expect(transport.requests.map(\.path) == ["/users/acme", "/graphql", Self.projectBase])
        #expect(transport.requests[1].jsonBody?["variables"] == ["input": ["ownerId": "O_acme", "title": "Roadmap"]])
    }

    @Test func updateProjectEditsThenCloses() async throws {
        let transport = Self.projectTransport(#"{"result":{"projectV2":{"number":2}}}"#)
        let (text, isError) = try await callTool("update_project", Self.with(Self.project, ["title": "Q3", "closed": true]), on: transport)
        #expect(!isError, "\(text)")
        let inputs = transport.requests.filter { $0.path == "/graphql" }.compactMap { $0.jsonBody?["variables"]?["input"] }
        #expect(inputs.map { $0["title"] } == [.string("Q3"), nil])
        #expect(inputs.map { $0["closed"] } == [nil, .bool(true)])
    }

    @Test func updateProjectNeedsAChange() async throws {
        let transport = Self.projectTransport("{}")
        let (text, isError) = try await callTool("update_project", Self.project, on: transport)
        #expect(isError)
        #expect(text == "Pass at least one field to change.")
    }

    @Test func deleteProject() async throws {
        let transport = Self.projectTransport(#"{"result":{"projectV2":{"number":2}}}"#)
        let (text, isError) = try await callTool("delete_project", Self.project, on: transport)
        #expect(!isError, "\(text)")
        #expect(text == "Deleted project 2.")
        #expect(transport.requests.last?.jsonBody?["query"]?.stringValue?.contains("deleteProjectV2") == true)
    }

    @Test func statusUpdates() async throws {
        let update =
            #"{"id":"PVTSU_1","fullDatabaseId":"77","body":"Going well","status":"ON_TRACK","startDate":"2026-01-01","targetDate":"2026-02-01","createdAt":"2026-01-02T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z"}"#
        let list = Self.projectTransport(#"{"node":{"statusUpdates":{"nodes":[\#(update)]}}}"#)
        let (listed, listFailed) = try await callTool("list_project_status_updates", Self.with(Self.project, ["limit": 5]), on: list)
        #expect(!listFailed, "\(listed)")
        #expect(listed.contains("Going well"))
        #expect(list.requests.last?.jsonBody?["variables"]?["first"] == 5)

        let create = Self.projectTransport(#"{"result":{"statusUpdate":\#(update)}}"#)
        let arguments = Self.with(Self.project, ["status": "on_track", "body": "Going well", "targetDate": "2026-02-01"])
        let (created, createFailed) = try await callTool("create_project_status_update", arguments, on: create)
        #expect(!createFailed, "\(created)")
        #expect(
            create.requests.last?.jsonBody?["variables"]?["input"]
                == ["projectId": "MDc6UHJvamVjdDEwMDI2MDM=", "status": "ON_TRACK", "body": "Going well", "targetDate": "2026-02-01"])
    }

    // MARK: Argument checks

    @Test func rejectsAmbiguousArguments() async throws {
        let transport = MockTransport(.json("{}"))
        #expect(try await callTool("get_user", ["login": "a", "id": 1], on: transport).isError)
        #expect(try await callTool("get_user", [:], on: transport).isError)
        #expect(try await callTool("update_profile", [:], on: transport).isError)
        #expect(try await callTool("invite_to_organization", ["org": "acme"], on: transport).isError)
        #expect(try await callTool("update_team", Self.with(Self.team, ["parentTeamID": 1, "topLevel": true]), on: transport).isError)
        #expect(try await callTool("get_project", ["org": "a", "user": "b", "project": 1], on: transport).isError)
        #expect(try await callTool("set_team_repository_role", Self.with(Self.team, ["owner": "a", "repo": "b"]), on: transport).isError)
        let twoValues = Self.with(Self.project, ["itemID": 1, "fieldID": 2, "text": "a", "number": 3])
        let (text, isError) = try await callTool("update_project_item", twoValues, on: transport)
        #expect(isError)
        #expect(text == "Pass exactly one of `text`, `number`, `date`, `optionID`, `iterationID`, or `clear`.")
        #expect(transport.requests.isEmpty)
    }

    @Test func projectFieldValuesOfEachKind() async throws {
        let values: [([String: MCP.Value], JSONValue)] = [
            (["number": 3.5], 3.5),
            (["date": "2026-01-09"], "2026-01-09"),
            (["clear": true], nil),
            (["iterationID": "iter_1"], "iter_1"),
        ]
        for (value, expected) in values {
            let transport = MockTransport(.fixture("projects-v2-item-simple"))
            let arguments = Self.with(Self.project, ["itemID": 17, "fieldID": 4]).merging(value) { _, new in new }
            let (text, isError) = try await callTool("update_project_item", arguments, on: transport)
            #expect(!isError, "\(text)")
            #expect(transport.requests.first?.jsonBody == ["fields": [["id": 4, "value": expected]]])
        }
    }
}
