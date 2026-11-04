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

@Suite("Repository webhooks")
struct RepositoryWebhooksTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let hook = try decoder.decode(RepositoryWebhook.self, from: loadFixture("hook"))
        #expect(hook.events == ["push", "pull_request"])
        #expect(hook.config.insecureSSL == false)
        #expect(hook.config.contentType == .json)
        #expect(hook.lastResponse?.status == "unused")
        #expect(hook.lastResponse?.code == nil)
        #expect(hook.testURL?.lastPathComponent == "test")
        _ = try decoder.decode([RepositoryWebhook].self, from: loadFixture("hook-items"))
    }

    @Test func webhookRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/hooks": .fixture("hook-items")
            case "GET /repos/o/r/hooks/1/config", "PATCH /repos/o/r/hooks/1/config": .fixture("webhook-config")
            case "GET /repos/o/r/hooks/1/deliveries": .fixture("hook-delivery-items")
            case "GET /repos/o/r/hooks/1/deliveries/9": .fixture("hook-delivery")
            case "POST /repos/o/r/hooks/1/deliveries/9/attempts": .json("{}", status: 202)
            case "DELETE /repos/o/r/hooks/1", "POST /repos/o/r/hooks/1/pings", "POST /repos/o/r/hooks/1/tests": .noContent()
            default: .fixture("hook")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.webhooks("o", "r").collect()
        _ = try await repos.webhook(id: 1, in: "o", "r")
        _ = try await repos.createWebhook(
            NewWebhook(config: WebhookConfiguration(url: URL(string: "https://example.com/hook"), contentType: .json, secret: "s3"), events: ["*"]),
            in: "o", "r")
        _ = try await repos.updateWebhook(id: 1, in: "o", "r", WebhookUpdate(addEvents: ["release"], removeEvents: ["push"], active: false))
        try await repos.deleteWebhook(id: 1, in: "o", "r")
        _ = try await repos.webhookConfiguration(id: 1, in: "o", "r")
        _ = try await repos.updateWebhookConfiguration(id: 1, in: "o", "r", WebhookConfiguration(insecureSSL: false))
        _ = try await repos.webhookDeliveries(id: 1, in: "o", "r", status: .failure).collect()
        let delivery = try await repos.webhookDelivery(9, webhook: 1, in: "o", "r")
        try await repos.redeliver(9, webhook: 1, in: "o", "r")
        try await repos.pingWebhook(id: 1, in: "o", "r")
        try await repos.testWebhook(id: 1, in: "o", "r")

        #expect(delivery.delivery.event == "issues")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/hooks", "GET /repos/o/r/hooks/1", "POST /repos/o/r/hooks", "PATCH /repos/o/r/hooks/1",
                "DELETE /repos/o/r/hooks/1", "GET /repos/o/r/hooks/1/config", "PATCH /repos/o/r/hooks/1/config",
                "GET /repos/o/r/hooks/1/deliveries", "GET /repos/o/r/hooks/1/deliveries/9", "POST /repos/o/r/hooks/1/deliveries/9/attempts",
                "POST /repos/o/r/hooks/1/pings", "POST /repos/o/r/hooks/1/tests",
            ])
        #expect(
            transport.requests[2].jsonBody == [
                "name": "web", "events": ["*"], "active": true,
                "config": ["url": "https://example.com/hook", "content_type": "json", "secret": "s3"],
            ])
        #expect(transport.requests[3].jsonBody == ["add_events": ["release"], "remove_events": ["push"], "active": false])
        #expect(transport.requests[6].jsonBody == ["insecure_ssl": "0"])
        #expect(transport.requests[7].queryItems == ["status": "failure", "per_page": "100"])
    }
}
