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

@Suite("Organization settings")
struct OrganizationSettingsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func propertyModelsDecode() throws {
        let properties = try decoder.decode([CustomProperty].self, from: loadFixture("custom-properties"))
        let environment = try #require(properties.first)
        #expect(environment.name == "environment")
        #expect(environment.valueType == .singleSelect)
        #expect(environment.defaultValue == "production")
        #expect(environment.allowedValues == ["production", "development"])
        _ = try decoder.decode(CustomProperty.self, from: loadFixture("custom-property"))

        let values = try decoder.decode([RepositoryPropertyValues].self, from: loadFixture("org-repo-custom-property-values"))
        #expect(values.first?["service"] == "web")

        let external = try decoder.decode([ExternalProperty].self, from: loadFixture("external-properties"))
        #expect(external.map(\.name) == ["environment", "business_unit"])
        let installation = try decoder.decode(
            ExternalPropertyInstallation.self, from: loadFixture("organization-external-property-installation"))
        #expect(installation.installationID == 1)
    }

    @Test func propertyValueDecodesStringsAndLists() throws {
        #expect(try decoder.decode(PropertyValue.self, from: Data(#""a""#.utf8)) == "a")
        #expect(try decoder.decode(PropertyValue.self, from: Data(#"["a","b"]"#.utf8)) == ["a", "b"])
    }

    @Test func insightsModelsDecode() throws {
        let routes = try decoder.decode([APIRouteUsage].self, from: loadFixture("api-insights-route-stats"))
        #expect(routes.first?.apiRoute == "/repositories/:repository_id")
        #expect(routes.first?.lastRateLimitedAt != nil)
        _ = try decoder.decode([APISubjectUsage].self, from: loadFixture("api-insights-subject-stats"))
        _ = try decoder.decode([APIActorUsage].self, from: loadFixture("api-insights-user-stats"))
        let samples = try decoder.decode([APIUsageSample].self, from: loadFixture("api-insights-time-stats"))
        #expect(samples.count > 1)
        let summary = try decoder.decode(APIUsageSummary.self, from: loadFixture("api-insights-summary-stats"))
        #expect(summary.totalRequestCount != nil)
    }

    // MARK: Requests

    @Test func propertyDefinitionRequests() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("DELETE", _): .noContent()
            case (_, "/orgs/acme/properties/schema"): .fixture("custom-properties")
            default: .fixture("custom-property")
            }
        }
        let orgs = makeClient(transport).organizations
        let tier = CustomProperty(name: "tier", valueType: .singleSelect, required: true, defaultValue: "gold", allowedValues: ["gold", "silver"])
        _ = try await orgs.customProperties(of: "acme")
        _ = try await orgs.customProperty("tier", in: "acme")
        _ = try await orgs.setCustomProperties([tier], in: "acme")
        _ = try await orgs.setCustomProperty(tier, in: "acme")
        try await orgs.deleteCustomProperty("tier", in: "acme")
        #expect(
            transport.requests[2].jsonBody == [
                "properties": [
                    [
                        "property_name": "tier", "value_type": "single_select", "required": true, "default_value": "gold",
                        "allowed_values": ["gold", "silver"],
                    ]
                ]
            ])
        #expect(transport.requests[3].httpMethod == "PUT")
        #expect(transport.requests[3].path == "/orgs/acme/properties/schema/tier")
        #expect(
            transport.requests[3].jsonBody == [
                "value_type": "single_select", "required": true, "default_value": "gold", "allowed_values": ["gold", "silver"],
            ])
        #expect(transport.requests[4].httpMethod == "DELETE")
    }

    @Test func propertyValueRequests() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("org-repo-custom-property-values") : .noContent()
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.customPropertyValues(in: "acme", repositoryQuery: "props.tier:gold").collect()
        try await orgs.setCustomPropertyValues(
            [CustomPropertyValue("tier", "gold"), CustomPropertyValue("team", nil)], onRepositories: ["api", "web"], in: "acme")
        #expect(transport.requests[0].queryItems == ["repository_query": "props.tier:gold", "per_page": "100"])
        #expect(
            transport.requests[1].jsonBody == [
                "repository_names": ["api", "web"],
                "properties": [["property_name": "tier", "value": "gold"], ["property_name": "team", "value": nil]],
            ])
    }

    @Test func externalPropertyRequests() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", "/orgs/acme/properties/installations"): .json("[]")
            case ("GET", _): .fixture("external-properties")
            case ("POST", _): .fixture("organization-external-property-installation", status: 201)
            default: .noContent()
            }
        }
        let orgs = makeClient(transport).organizations
        _ = try await orgs.externalPropertyInstallations(of: "acme")
        _ = try await orgs.registerExternalPropertyInstallation(1, displayName: "Acme", in: "acme")
        _ = try await orgs.externalProperties(of: "acme")
        try await orgs.setExternalPropertyValues([CustomPropertyValue("environment", "prod")], onRepositories: ["api"], in: "acme")
        try await orgs.setExternalPropertyValue("environment", values: ["web": "dev", "api": nil], in: "acme")
        try await orgs.deleteExternalPropertyValues("environment", in: "acme")
        #expect(transport.requests[1].jsonBody == ["installation_id": 1, "display_name": "Acme"])
        #expect(transport.requests[3].path == "/orgs/acme/properties/installations/values")
        #expect(
            transport.requests[4].jsonBody == [
                "repository_values": [["repository_name": "api", "value": nil], ["repository_name": "web", "value": "dev"]]
            ])
        #expect(
            transport.requests.map { "\($0.httpMethod!) \($0.path)" }.last
                == "DELETE /orgs/acme/properties/installations/values/environment")
    }

    @Test func immutableReleases() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", "/orgs/acme/settings/immutable-releases"): .json(#"{"enforced_repositories":"selected"}"#)
            case ("GET", _): .fixture("public-repository-paginated")
            default: .noContent()
            }
        }
        let orgs = makeClient(transport).organizations
        let settings = try await orgs.immutableReleasesSettings(of: "acme")
        #expect(settings.enforcedRepositories == .selected)
        let repos = try await orgs.immutableReleasesRepositories(of: "acme").collect()
        #expect(repos.count == 1)
        try await orgs.setImmutableReleases(.selected(repositoryIDs: [1, 2]), in: "acme")
        try await orgs.setImmutableReleases(.all, in: "acme")
        try await orgs.setImmutableReleasesRepositories([3], in: "acme")
        try await orgs.enableImmutableReleases(forRepository: 4, in: "acme")
        try await orgs.disableImmutableReleases(forRepository: 4, in: "acme")
        #expect(transport.requests[2].jsonBody == ["enforced_repositories": "selected", "selected_repository_ids": [1, 2]])
        #expect(transport.requests[3].jsonBody == ["enforced_repositories": "all"])
        #expect(transport.requests[4].jsonBody == ["selected_repository_ids": [3]])
        #expect(
            transport.requests.dropFirst(5).map { "\($0.httpMethod!) \($0.path)" } == [
                "PUT /orgs/acme/settings/immutable-releases/repositories/4",
                "DELETE /orgs/acme/settings/immutable-releases/repositories/4",
            ])
    }

    @Test func insightsPathsAndQueries() async throws {
        let transport = MockTransport { request, _ in
            let stats = request.path.split(separator: "/")[4]
            return .fixture("api-insights-\(stats)")
        }
        let orgs = makeClient(transport).organizations
        let window = APIUsageWindow(from: Date(timeIntervalSince1970: 0), to: Date(timeIntervalSince1970: 3600))
        let scopes: [APIUsageScope] = [.organization, .user(id: 9), .actor(.fineGrainedToken(id: 5))]
        for scope in scopes {
            #expect(try await orgs.apiUsageSummary(in: "acme", for: scope, during: window).totalRequestCount == 34225)
        }
        for scope in scopes {
            let samples = try await orgs.apiUsageOverTime(in: "acme", for: scope, during: window, every: .hour)
            #expect(samples.first?.totalRequestCount == 34225)
        }
        let routes = try await orgs.apiRouteUsage(in: "acme", by: .installation(id: 2), during: window, sortedBy: .totalRequests).collect()
        #expect(routes.first?.apiRoute == "/repositories/:repository_id")
        let subjects = try await orgs.apiSubjectUsage(in: "acme", during: window, ascending: true, subjectContaining: "api").collect()
        #expect(subjects.first?.subjectName == "GitHub Actions")
        let actors = try await orgs.apiActorUsage(in: "acme", forUser: 9, during: window, actorContaining: "Actions").collect()
        #expect(actors.first?.actorType == "oauth_app")
        #expect(
            transport.requests.map(\.route) == [
                "GET /orgs/acme/insights/api/summary-stats",
                "GET /orgs/acme/insights/api/summary-stats/users/9",
                "GET /orgs/acme/insights/api/summary-stats/fine_grained_pat/5",
                "GET /orgs/acme/insights/api/time-stats",
                "GET /orgs/acme/insights/api/time-stats/users/9",
                "GET /orgs/acme/insights/api/time-stats/fine_grained_pat/5",
                "GET /orgs/acme/insights/api/route-stats/installation/2",
                "GET /orgs/acme/insights/api/subject-stats",
                "GET /orgs/acme/insights/api/user-stats/9",
            ])
        let timeWindow = ["min_timestamp": "1970-01-01T00:00:00Z", "max_timestamp": "1970-01-01T01:00:00Z"]
        #expect(transport.requests[0..<3].allSatisfy { $0.queryItems == timeWindow })
        #expect(transport.requests[3..<6].allSatisfy { $0.queryItems == timeWindow.merging(["timestamp_increment": "1h"]) { a, _ in a } })
        #expect(
            transport.requests[6].queryItems
                == timeWindow.merging(["sort": "total_request_count", "direction": "desc", "per_page": "100"]) { a, _ in a })
        #expect(
            transport.requests[7].queryItems
                == timeWindow.merging(["direction": "asc", "subject_name_substring": "api", "per_page": "100"]) { a, _ in a })
        #expect(
            transport.requests[8].queryItems
                == timeWindow.merging(["direction": "desc", "actor_name_substring": "Actions", "per_page": "100"]) { a, _ in a })
    }
}
