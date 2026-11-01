import Foundation
import Testing

@testable import GHKit

@Suite("Organization admin")
struct OrganizationAdminTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func webhookModelsDecode() throws {
        let hook = try decoder.decode(OrganizationWebhook.self, from: loadFixture("org-hook"))
        #expect(hook.name == "web")
        #expect(hook.config.contentType == .json)
        #expect(hook.config.insecureSSL == nil)
        _ = try decoder.decode([OrganizationWebhook].self, from: loadFixture("org-hook-items"))

        let config = try decoder.decode(WebhookConfiguration.self, from: loadFixture("webhook-config"))
        #expect(config.url != nil)

        let deliveries = try decoder.decode([WebhookDelivery].self, from: loadFixture("hook-delivery-items"))
        #expect(deliveries.first?.succeeded == true)

        let detail = try decoder.decode(WebhookDeliveryDetail.self, from: loadFixture("hook-delivery"))
        #expect(detail.delivery.event == "issues")
        #expect(detail.request.headers?["X-GitHub-Event"] == "issues")
        #expect(detail.request.payload != nil)
    }

    @Test(arguments: [(#""1""#, true), (#""0""#, false), ("1", true), ("0", false)])
    func insecureSSLAcceptsStringsAndNumbers(json: String, expected: Bool) throws {
        let config = try decoder.decode(WebhookConfiguration.self, from: Data(#"{"insecure_ssl":\#(json)}"#.utf8))
        #expect(config.insecureSSL == expected)
    }

    @Test func roleModelsDecode() throws {
        let role = try decoder.decode(OrganizationRoleDefinition.self, from: loadFixture("organization-role"))
        #expect(!role.permissions.isEmpty)
        #expect(role.organization?.login == "github")
        let teams = try decoder.decode([TeamRoleAssignment].self, from: loadFixture("team-items"))
        #expect(teams.first?.team.slug == "justice-league")
        let users = try decoder.decode([UserRoleAssignment].self, from: loadFixture("simple-user-items"))
        #expect(users.first?.user.login == "octocat")
    }

    @Test func tokenModelsDecode() throws {
        let requests = try decoder.decode([PersonalAccessTokenRequest].self, from: loadFixture("org-pat-grant-request-paginated"))
        #expect(requests.first?.repositorySelection == .all)
        #expect(requests.first?.permissions.organization?["members"] != nil)
        let grants = try decoder.decode([PersonalAccessTokenGrant].self, from: loadFixture("org-pat-grant-paginated"))
        #expect(grants.first?.tokenExpired == false)
        let repos = try decoder.decode([MinimalRepository].self, from: loadFixture("minimal-repository-items"))
        #expect(repos.first?.fullName == "octocat/Hello-World")
    }

    // MARK: Requests

    @Test func createAndUpdateWebhook() async throws {
        let transport = MockTransport(.fixture("org-hook"))
        let orgs = makeClient(transport).organizations
        let url = URL(string: "https://example.com/hook")!
        _ = try await orgs.createWebhook(
            NewWebhook(config: WebhookConfiguration(url: url, contentType: .json, secret: "s3cret"), events: ["push", "issues"]),
            in: "acme")
        _ = try await orgs.updateWebhook(id: 1, in: "acme", WebhookUpdate(active: false))
        _ = try await orgs.updateWebhookConfiguration(id: 1, in: "acme", WebhookConfiguration(insecureSSL: false))
        #expect(transport.requests[0].path == "/orgs/acme/hooks")
        #expect(
            transport.requests[0].jsonBody == [
                "name": "web", "active": true, "events": ["push", "issues"],
                "config": ["url": "https://example.com/hook", "content_type": "json", "secret": "s3cret"],
            ])
        #expect(transport.requests[1].httpMethod == "PATCH")
        #expect(transport.requests[1].jsonBody == ["active": false])
        #expect(transport.requests[2].path == "/orgs/acme/hooks/1/config")
        #expect(transport.requests[2].jsonBody == ["insecure_ssl": "0"])
    }

    @Test func webhookCalls() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/orgs/acme/hooks": .fixture("org-hook-items")
            case "/orgs/acme/hooks/1": request.httpMethod == "DELETE" ? .noContent() : .fixture("org-hook")
            case "/orgs/acme/hooks/1/config": .fixture("webhook-config")
            case "/orgs/acme/hooks/1/deliveries": .fixture("hook-delivery-items")
            case "/orgs/acme/hooks/1/deliveries/9": .fixture("hook-delivery")
            default: .noContent()
            }
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.webhooks(of: "acme").collect()
        _ = try await orgs.webhook(id: 1, in: "acme")
        _ = try await orgs.webhookConfiguration(id: 1, in: "acme")
        _ = try await orgs.webhookDeliveries(id: 1, in: "acme", status: .failure).collect()
        _ = try await orgs.webhookDelivery(9, webhook: 1, in: "acme")
        try await orgs.redeliver(9, webhook: 1, in: "acme")
        try await orgs.pingWebhook(id: 1, in: "acme")
        try await orgs.deleteWebhook(id: 1, in: "acme")
        #expect(transport.requests[3].queryItems == ["status": "failure", "per_page": "100"])
        #expect(
            transport.requests.dropFirst(5).map { "\($0.httpMethod!) \($0.path)" } == [
                "POST /orgs/acme/hooks/1/deliveries/9/attempts", "POST /orgs/acme/hooks/1/pings", "DELETE /orgs/acme/hooks/1",
            ])
    }

    @Test func rolesUnwrapAndAssign() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/orgs/acme/organization-roles": .fixture("organization-role-list")
            case "/orgs/acme/organization-roles/8030": .fixture("organization-role")
            case "/orgs/acme/organization-roles/8030/teams": .fixture("team-items")
            case "/orgs/acme/organization-roles/8030/users": .fixture("simple-user-items")
            default: .noContent()
            }
        }
        let orgs = makeClient(transport).organizations
        let roles = try await orgs.roles(of: "acme")
        #expect(roles.count == 2)
        _ = try await orgs.role(id: 8030, in: "acme")
        _ = try await orgs.teams(withRole: 8030, in: "acme").collect()
        _ = try await orgs.users(withRole: 8030, in: "acme").collect()
        try await orgs.assignRole(8030, toTeam: "core", in: "acme")
        try await orgs.revokeRole(8030, fromTeam: "core", in: "acme")
        try await orgs.revokeAllRoles(fromTeam: "core", in: "acme")
        try await orgs.assignRole(8030, toUser: "mona", in: "acme")
        try await orgs.revokeRole(8030, fromUser: "mona", in: "acme")
        try await orgs.revokeAllRoles(fromUser: "mona", in: "acme")
        #expect(
            transport.requests.dropFirst(4).map { "\($0.httpMethod!) \($0.path)" } == [
                "PUT /orgs/acme/organization-roles/teams/core/8030", "DELETE /orgs/acme/organization-roles/teams/core/8030",
                "DELETE /orgs/acme/organization-roles/teams/core", "PUT /orgs/acme/organization-roles/users/mona/8030",
                "DELETE /orgs/acme/organization-roles/users/mona/8030", "DELETE /orgs/acme/organization-roles/users/mona",
            ])
    }

    @Test func tokenFilterBuildsArrayQuery() async throws {
        let transport = MockTransport(.json("[]"))
        let filter = TokenFilter(
            owners: ["mona", "hubot"], permission: "issues_read",
            lastUsedAfter: Date(timeIntervalSince1970: 0), tokenIDs: [3], ascending: true)
        _ = try await makeClient(transport).organizations.tokenGrants(in: "acme", matching: filter).collect()
        let request = try #require(transport.requests.first)
        let items = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.filter { $0.name == "owner[]" }.map(\.value) == ["mona", "hubot"])
        #expect(items.contains(URLQueryItem(name: "token_id[]", value: "3")))
        #expect(items.contains(URLQueryItem(name: "direction", value: "asc")))
        #expect(items.contains(URLQueryItem(name: "last_used_after", value: "1970-01-01T00:00:00Z")))
        #expect(items.contains(URLQueryItem(name: "permission", value: "issues_read")))
    }

    @Test func tokenReviewsAndRevocations() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("minimal-repository-items") : .noContent()
        }
        let orgs = makeClient(transport).organizations
        try await orgs.reviewTokenRequest(id: 7, in: "acme", .deny, reason: "Too broad")
        try await orgs.reviewTokenRequests(ids: [7, 8], in: "acme", .approve)
        try await orgs.revokeTokenGrant(id: 3, in: "acme")
        try await orgs.revokeTokenGrants(ids: [3, 4], in: "acme")
        _ = try await orgs.tokenRequestRepositories(id: 7, in: "acme").collect()
        _ = try await orgs.tokenGrantRepositories(id: 3, in: "acme").collect()
        #expect(transport.requests[0].path == "/orgs/acme/personal-access-token-requests/7")
        #expect(transport.requests[0].jsonBody == ["action": "deny", "reason": "Too broad"])
        #expect(transport.requests[1].jsonBody == ["action": "approve", "pat_request_ids": [7, 8]])
        #expect(transport.requests[2].path == "/orgs/acme/personal-access-tokens/3")
        #expect(transport.requests[2].jsonBody == ["action": "revoke"])
        #expect(transport.requests[3].jsonBody == ["action": "revoke", "pat_ids": [3, 4]])
        #expect(
            transport.requests.dropFirst(4).map(\.path) == [
                "/orgs/acme/personal-access-token-requests/7/repositories", "/orgs/acme/personal-access-tokens/3/repositories",
            ])
    }
}
