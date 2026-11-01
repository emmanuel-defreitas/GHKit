import Foundation
import Testing

@testable import GHKit

@Suite("Organizations")
struct OrganizationsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func organizationModelsDecode() throws {
        let org = try decoder.decode(Organization.self, from: loadFixture("organization-full"))
        #expect(org.login == "github")
        #expect(org.plan?.filledSeats == 4)
        #expect(org.defaultRepositoryPermission == .read)
        #expect(org.createdAt != nil)

        let orgs = try decoder.decode([SimpleOrganization].self, from: loadFixture("organization-simple-items"))
        #expect(orgs.first?.login == "github")

        let membership = try decoder.decode(OrganizationMembership.self, from: loadFixture("org-membership"))
        #expect(membership.state == .pending)
        #expect(membership.role == .admin)
        #expect(membership.enterpriseTeamsProvidingIndirectMembership?.count == 2)
        let admin = try decoder.decode(OrganizationMembership.self, from: loadFixture("org-membership-admin"))
        #expect(admin.state == .active)
        _ = try decoder.decode([OrganizationMembership].self, from: loadFixture("org-membership-items"))

        let teams = try decoder.decode([Team].self, from: loadFixture("team-items"))
        #expect(teams.first?.slug == "justice-league")
        #expect(teams.first?.parent == nil)
    }

    @Test func invitationTreatsEmptyStringsAsMissing() throws {
        let invitations = try decoder.decode([OrganizationInvitation].self, from: loadFixture("organization-invitation-items"))
        let invitation = try #require(invitations.first)
        #expect(invitation.role == .directMember)
        #expect(invitation.createdAt != nil)
        #expect(invitation.failedAt == nil)
        #expect(invitation.failedReason == nil)
        #expect(invitation.inviter?.login == "other_user")
    }

    // MARK: Requests

    @Test func updateSendsOnlyChangedFields() async throws {
        let transport = MockTransport(.fixture("organization-full"))
        _ = try await makeClient(transport).organizations.update(
            "acme", OrganizationUpdate(description: "Rockets", defaultRepositoryPermission: .write))
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PATCH")
        #expect(request.path == "/orgs/acme")
        #expect(request.jsonBody == ["description": "Rockets", "default_repository_permission": "write"])
    }

    @Test func organizationLists() async throws {
        let transport = MockTransport(.fixture("organization-simple-items"))
        let orgs = makeClient(transport).organizations
        _ = try await orgs.all(since: 7).collect()
        _ = try await orgs.list().collect()
        _ = try await orgs.list(of: "octocat").collect()
        #expect(transport.requests.map(\.path) == ["/organizations", "/user/orgs", "/users/octocat/orgs"])
        #expect(transport.requests[0].queryItems == ["since": "7", "per_page": "100"])
    }

    @Test func installationsUnwrapTheList() async throws {
        let installation = String(decoding: loadFixture("installation"), as: UTF8.self)
        let transport = MockTransport(.json(#"{"total_count":1,"installations":[\#(installation)]}"#))
        let installations = try await makeClient(transport).organizations.installations(of: "acme").collect()
        #expect(installations.count == 1)
        #expect(transport.requests.first?.path == "/orgs/acme/installations")
    }

    @Test func memberListFilters() async throws {
        let transport = MockTransport(.json("[]"))
        let orgs = makeClient(transport).organizations
        _ = try await orgs.members(of: "acme", filter: .twoFactorDisabled, role: .admin).collect()
        _ = try await orgs.outsideCollaborators(of: "acme", filter: .twoFactorInsecure).collect()
        _ = try await orgs.publicMembers(of: "acme").collect()
        _ = try await orgs.blockedUsers(in: "acme").collect()
        #expect(transport.requests[0].queryItems == ["filter": "2fa_disabled", "role": "admin", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["filter": "2fa_insecure", "per_page": "100"])
        #expect(
            transport.requests.map(\.path) == [
                "/orgs/acme/members", "/orgs/acme/outside_collaborators", "/orgs/acme/public_members", "/orgs/acme/blocks",
            ])
    }

    @Test(arguments: [(204, true), (404, false)])
    func checkEndpointsMapStatusToBool(status: Int, expected: Bool) async throws {
        let transport = MockTransport(MockResponse(status: status))
        let orgs = makeClient(transport).organizations
        #expect(try await orgs.isMember("mona", of: "acme") == expected)
        #expect(try await orgs.isPublicMember("mona", of: "acme") == expected)
        #expect(try await orgs.isBlocked("spammer", in: "acme") == expected)
        #expect(
            transport.requests.map(\.path) == [
                "/orgs/acme/members/mona", "/orgs/acme/public_members/mona", "/orgs/acme/blocks/spammer",
            ])
    }

    @Test func membershipChanges() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("org-membership")
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.setMembership(of: "mona", in: "acme", role: .admin)
        try await orgs.removeMembership(of: "mona", from: "acme")
        try await orgs.removeMember("hubot", from: "acme")
        _ = try await orgs.acceptInvitation(to: "acme")
        #expect(transport.requests[0].httpMethod == "PUT")
        #expect(transport.requests[0].path == "/orgs/acme/memberships/mona")
        #expect(transport.requests[0].jsonBody == ["role": "admin"])
        #expect(
            transport.requests.dropFirst().map { "\($0.httpMethod!) \($0.path)" } == [
                "DELETE /orgs/acme/memberships/mona", "DELETE /orgs/acme/members/hubot", "PATCH /user/memberships/orgs/acme",
            ])
        #expect(transport.requests[3].jsonBody == ["state": "active"])
    }

    @Test func yourMemberships() async throws {
        let transport = MockTransport { request, _ in
            request.path == "/user/memberships/orgs" ? .fixture("org-membership-items") : .fixture("org-membership")
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.memberships(state: .pending).collect()
        _ = try await orgs.membership(in: "acme")
        _ = try await orgs.membership(of: "mona", in: "acme")
        #expect(transport.requests[0].queryItems == ["state": "pending", "per_page": "100"])
        #expect(transport.requests.map(\.path).dropFirst() == ["/user/memberships/orgs/acme", "/orgs/acme/memberships/mona"])
    }

    @Test func visibilityCollaboratorsAndBlocks() async throws {
        let transport = MockTransport(.noContent())
        let orgs = makeClient(transport).organizations
        try await orgs.publicizeMembership(of: "mona", in: "acme")
        try await orgs.concealMembership(of: "mona", in: "acme")
        try await orgs.convertToOutsideCollaborator("mona", in: "acme", async: true)
        try await orgs.removeOutsideCollaborator("mona", from: "acme")
        try await orgs.block("spammer", in: "acme")
        try await orgs.unblock("spammer", in: "acme")
        try await orgs.delete("acme")
        #expect(
            transport.requests.map { "\($0.httpMethod!) \($0.path)" } == [
                "PUT /orgs/acme/public_members/mona", "DELETE /orgs/acme/public_members/mona",
                "PUT /orgs/acme/outside_collaborators/mona", "DELETE /orgs/acme/outside_collaborators/mona",
                "PUT /orgs/acme/blocks/spammer", "DELETE /orgs/acme/blocks/spammer", "DELETE /orgs/acme",
            ])
        #expect(transport.requests[2].jsonBody == ["async": true])
    }

    @Test func invitations() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("POST", _): .fixture("organization-invitation", status: 201)
            case ("DELETE", _): .noContent()
            case (_, "/orgs/acme/invitations/5/teams"): .fixture("team-items")
            default: .fixture("organization-invitation-items")
            }
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.invite(NewOrganizationInvitation(.user(id: 42), role: .admin, teamIDs: [1, 2]), to: "acme")
        _ = try await orgs.invite(NewOrganizationInvitation(.email("mona@example.com")), to: "acme")
        _ = try await orgs.invitations(of: "acme", role: .billingManager, source: .scim).collect()
        _ = try await orgs.failedInvitations(of: "acme").collect()
        let teams = try await orgs.invitationTeams(id: 5, in: "acme").collect()
        try await orgs.cancelInvitation(id: 5, in: "acme")
        #expect(transport.requests[0].jsonBody == ["invitee_id": 42, "role": "admin", "team_ids": [1, 2]])
        #expect(transport.requests[1].jsonBody == ["email": "mona@example.com", "role": "direct_member"])
        #expect(
            transport.requests[2].queryItems == ["role": "billing_manager", "invitation_source": "scim", "per_page": "100"])
        #expect(teams.count == 1)
        #expect(
            transport.requests.dropFirst(3).map { "\($0.httpMethod!) \($0.path)" } == [
                "GET /orgs/acme/failed_invitations", "GET /orgs/acme/invitations/5/teams", "DELETE /orgs/acme/invitations/5",
            ])
    }
}
