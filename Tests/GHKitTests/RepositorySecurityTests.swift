import Foundation
import Testing

@testable import GHKit

@Suite("Repository security settings")
struct RepositorySecurityTests {
    @Test func checksAndToggles() async throws {
        let transport = MockTransport { request, index in
            switch request.route {
            case "GET /repos/o/r/vulnerability-alerts": index == 0 ? .noContent() : .json(#"{"message":"Not Found"}"#, status: 404)
            case "GET /repos/o/r/automated-security-fixes": .json(#"{"enabled":true,"paused":false}"#)
            case "GET /repos/o/r/private-vulnerability-reporting": .json(#"{"enabled":true}"#)
            case "GET /repos/o/r/immutable-releases": .json(#"{"enabled":true,"enforced_by_owner":true}"#)
            default: .noContent()
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.vulnerabilityAlertsEnabled("o", "r"))
        #expect(try await repos.vulnerabilityAlertsEnabled("o", "r") == false)
        try await repos.setVulnerabilityAlerts(enabled: true, in: "o", "r")
        try await repos.setVulnerabilityAlerts(enabled: false, in: "o", "r")
        #expect(try await repos.dependabotSecurityUpdates("o", "r") == DependabotSecurityUpdatesStatus(isEnabled: true, isPaused: false))
        try await repos.setDependabotSecurityUpdates(enabled: true, in: "o", "r")
        try await repos.setDependabotSecurityUpdates(enabled: false, in: "o", "r")
        #expect(try await repos.privateVulnerabilityReportingEnabled("o", "r"))
        try await repos.setPrivateVulnerabilityReporting(enabled: true, in: "o", "r")
        try await repos.setPrivateVulnerabilityReporting(enabled: false, in: "o", "r")
        #expect(try await repos.immutableReleases("o", "r").isEnforcedByOwner)
        try await repos.setImmutableReleases(enabled: true, in: "o", "r")
        try await repos.setImmutableReleases(enabled: false, in: "o", "r")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/vulnerability-alerts", "GET /repos/o/r/vulnerability-alerts", "PUT /repos/o/r/vulnerability-alerts",
                "DELETE /repos/o/r/vulnerability-alerts", "GET /repos/o/r/automated-security-fixes", "PUT /repos/o/r/automated-security-fixes",
                "DELETE /repos/o/r/automated-security-fixes",
                "GET /repos/o/r/private-vulnerability-reporting", "PUT /repos/o/r/private-vulnerability-reporting",
                "DELETE /repos/o/r/private-vulnerability-reporting",
                "GET /repos/o/r/immutable-releases", "PUT /repos/o/r/immutable-releases", "DELETE /repos/o/r/immutable-releases",
            ])
    }

    @Test func customPropertyValues() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("custom-property-values") : .noContent()
        }
        let repos = makeClient(transport).repositories
        let values = try await repos.customPropertyValues("o", "r")
        #expect(values.first == CustomPropertyValue("environment", "production"))
        try await repos.setCustomPropertyValues([CustomPropertyValue("team", ["a", "b"]), CustomPropertyValue("service", nil)], in: "o", "r")
        #expect(transport.requests[1].route == "PATCH /repos/o/r/properties/values")
        #expect(
            transport.requests[1].jsonBody == [
                "properties": [["property_name": "team", "value": ["a", "b"]], ["property_name": "service", "value": nil]]
            ])
    }

    @Test func dispatchEvent() async throws {
        let transport = MockTransport(.noContent())
        let repos = makeClient(transport).repositories
        try await repos.dispatch("deploy", payload: ["env": "prod", "dryRun": false], to: "o", "r")
        try await repos.dispatch("ping", to: "o", "r")
        #expect(transport.requests[0].route == "POST /repos/o/r/dispatches")
        #expect(transport.requests[0].jsonBody == ["event_type": "deploy", "client_payload": ["env": "prod", "dryRun": false]])
        #expect(transport.requests[1].jsonBody == ["event_type": "ping"])
    }
}
