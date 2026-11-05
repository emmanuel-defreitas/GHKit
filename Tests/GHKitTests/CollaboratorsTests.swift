import Foundation
import Testing

@testable import GHKitActivity
@testable import GHKitApps
@testable import GHKitCore
@testable import GHKitGists
@testable import GHKitIssues
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitPullRequests
@testable import GHKitRepositories
@testable import GHKitSearch
@testable import GHKitUsers

@Suite("Repository access")
struct CollaboratorsTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let collaborators = try decoder.decode([Collaborator].self, from: loadFixture("collaborator-items"))
        #expect(collaborators.first?.user.login == "octocat")
        #expect(collaborators.first?.permissions?.pull == true)
        #expect(collaborators.first?.roleName == "write")

        let permission = try decoder.decode(CollaboratorPermission.self, from: loadFixture("collaborator-permission"))
        #expect(permission.permission == "admin")
        #expect(permission.user?.user.login == "octocat")

        let invitation = try decoder.decode(RepositoryInvitation.self, from: loadFixture("repository-invitation"))
        #expect(invitation.repository.fullName == "octocat/Hello-World")
        _ = try decoder.decode([RepositoryInvitation].self, from: loadFixture("repository-invitation-items"))

        let key = try decoder.decode(DeployKey.self, from: loadFixture("deploy-key"))
        #expect(key.readOnly == true)
        #expect(key.addedBy == "octocat")
        #expect(key.lastUsed != nil)
        _ = try decoder.decode([DeployKey].self, from: loadFixture("deploy-key-items"))

        let autolink = try decoder.decode(Autolink.self, from: loadFixture("autolink"))
        #expect(autolink.keyPrefix == "TICKET-")
        _ = try decoder.decode([Autolink].self, from: loadFixture("autolink-items"))
    }

    @Test func collaboratorRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "PUT /repos/o/r/collaborators/mona": .fixture("repository-invitation", status: 201)
            case "PUT /repos/o/r/collaborators/member": .noContent()
            case "GET /repos/o/r/collaborators": .fixture("collaborator-items")
            case "GET /repos/o/r/collaborators/mona": .noContent()
            case "GET /repos/o/r/collaborators/mona/permission": .fixture("collaborator-permission")
            case "DELETE /repos/o/r/collaborators/mona": .noContent()
            default: .json(#"{"message":"Not Found"}"#, status: 404)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.collaborators("o", "r", affiliation: .outside, role: .maintain).collect()
        #expect(try await repos.isCollaborator("mona", on: "o", "r"))
        _ = try await repos.permission(of: "mona", on: "o", "r")
        let invitation = try await repos.addCollaborator("mona", to: "o", "r", role: .admin)
        let noInvitation = try await repos.addCollaborator("member", to: "o", "r")
        try await repos.removeCollaborator("mona", from: "o", "r")
        #expect(invitation != nil)
        #expect(noInvitation == nil)
        #expect(transport.requests[0].queryItems == ["affiliation": "outside", "permission": "maintain", "per_page": "100"])
        #expect(transport.requests[3].jsonBody == ["permission": "admin"])
        #expect(transport.requests[4].jsonBody == ["permission": "push"])
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/collaborators", "GET /repos/o/r/collaborators/mona",
                "GET /repos/o/r/collaborators/mona/permission", "PUT /repos/o/r/collaborators/mona",
                "PUT /repos/o/r/collaborators/member", "DELETE /repos/o/r/collaborators/mona",
            ])
    }

    @Test func invitationRequests() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", _): .fixture("repository-invitation-items")
            case ("PATCH", "/repos/o/r/invitations/1"): .fixture("repository-invitation")
            default: .noContent()
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.invitations("o", "r").collect()
        _ = try await repos.updateInvitation(id: 1, on: "o", "r", permission: .triage)
        try await repos.cancelInvitation(id: 1, on: "o", "r")
        _ = try await repos.myInvitations().collect()
        try await repos.acceptInvitation(id: 2)
        try await repos.declineInvitation(id: 3)
        #expect(transport.requests[1].jsonBody == ["permissions": "triage"])
        #expect(
            transport.requests.map { "\($0.httpMethod!) \($0.path)" } == [
                "GET /repos/o/r/invitations", "PATCH /repos/o/r/invitations/1", "DELETE /repos/o/r/invitations/1",
                "GET /user/repository_invitations", "PATCH /user/repository_invitations/2",
                "DELETE /user/repository_invitations/3",
            ])
    }

    @Test func deployKeysAndAutolinks() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/keys": .fixture("deploy-key-items")
            case "GET /repos/o/r/keys/1": .fixture("deploy-key")
            case "POST /repos/o/r/keys": .fixture("deploy-key", status: 201)
            case "DELETE /repos/o/r/keys/1", "DELETE /repos/o/r/autolinks/1": .noContent()
            case "GET /repos/o/r/autolinks": .fixture("autolink-items")
            case "GET /repos/o/r/autolinks/1": .fixture("autolink")
            case "POST /repos/o/r/autolinks": .fixture("autolink", status: 201)
            default: .json(#"{"message":"Not Found"}"#, status: 404)
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.deployKeys("o", "r").collect().first?.title == "octocat@octomac")
        #expect(try await repos.deployKey(id: 1, in: "o", "r").id == 1)
        #expect(try await repos.addDeployKey("ssh-ed25519 AAAA", title: "CI", to: "o", "r").verified == true)
        try await repos.deleteDeployKey(id: 1, from: "o", "r")
        #expect(try await repos.autolinks("o", "r").collect().first?.keyPrefix == "TICKET-")
        #expect(try await repos.autolink(id: 1, in: "o", "r").urlTemplate == "https://example.com/TICKET?query=<num>")
        let created = try await repos.createAutolink(
            prefix: "JIRA-", urlTemplate: "https://jira.example.com/browse/JIRA-<num>", in: "o", "r")
        #expect(created.isAlphanumeric)
        try await repos.deleteAutolink(id: 1, from: "o", "r")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/keys", "GET /repos/o/r/keys/1", "POST /repos/o/r/keys", "DELETE /repos/o/r/keys/1",
                "GET /repos/o/r/autolinks", "GET /repos/o/r/autolinks/1", "POST /repos/o/r/autolinks",
                "DELETE /repos/o/r/autolinks/1",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[2].jsonBody == ["key": "ssh-ed25519 AAAA", "title": "CI", "read_only": true])
        #expect(
            transport.requests[6].jsonBody == [
                "key_prefix": "JIRA-", "url_template": "https://jira.example.com/browse/JIRA-<num>", "is_alphanumeric": true,
            ])
    }
}
