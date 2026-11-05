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

@Suite("Core types")
struct CoreTests {
    @Test func linkHeaderKeepsCommasInsideURLs() {
        let header = #"<https://api.github.com/orgs/acme/projectsV2/1/items?fields=1,2&after=abc>; rel="next", <https://api.github.com/x?page=9>; rel="last""#
        let links = LinkHeader(header)
        #expect(links.next?.absoluteString == "https://api.github.com/orgs/acme/projectsV2/1/items?fields=1,2&after=abc")
        #expect(links.last?.absoluteString == "https://api.github.com/x?page=9")
        #expect(links.previous == nil)
    }

    @Test func emptyLinkHeader() {
        #expect(LinkHeader("").links.isEmpty)
    }

    @Test(arguments: ["2025-07-23", "2025-07-23T10:00:00Z"])
    func calendarDateDecodes(_ raw: String) throws {
        let date = try JSONDecoder().decode(CalendarDate.self, from: Data("\"\(raw)\"".utf8))
        #expect(date == CalendarDate(year: 2025, month: 7, day: 23))
        #expect(date.description == "2025-07-23")
    }

    @Test func calendarDateOrdering() {
        #expect(CalendarDate(year: 2025, month: 1, day: 31) < CalendarDate(year: 2025, month: 2, day: 1))
        #expect(CalendarDate("2025-13-01") == nil)
    }

    @Test func richTextDecodesStringOrObject() throws {
        let plain = try JSONDecoder().decode(RichText.self, from: Data(#""Sprint 1""#.utf8))
        let rich = try JSONDecoder().decode(RichText.self, from: Data(#"{"raw":"**Hi**","html":"<b>Hi</b>"}"#.utf8))
        #expect(plain.raw == "Sprint 1" && plain.html == "Sprint 1")
        #expect(rich.raw == "**Hi**" && rich.html == "<b>Hi</b>")
    }

    @Test func jsonValueRoundTripsAndReads() throws {
        let value: JSONValue = ["name": "Done", "count": 3, "tags": ["a", nil], "ok": true]
        let data = try GitHubJSON.encoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
        #expect(decoded["name"]?.stringValue == "Done")
        #expect(decoded["count"]?.intValue == 3)
        #expect(decoded["tags"]?[1]?.isNull == true)
        #expect(decoded["ok"]?.boolValue == true)
    }

    @Test(arguments: ["2022-04-28T12:00:00Z", "2022-04-28T12:00:00.123Z", "2022-04-28T14:00:00+02:00"])
    func parsesTimestamps(_ raw: String) throws {
        let date = try #require(GitHubJSON.parseDate(raw))
        #expect(abs(date.timeIntervalSince1970 - 1_651_147_200) < 1)
    }

    @Test func formEncodingEscapesReservedCharacters() {
        #expect(FormEncoding.encode(["scope": "repo read:org", "a": "x&y"]) == "a=x%26y&scope=repo%20read%3Aorg")
    }

    @Test func responseMetadataParsesGitHubHeaders() {
        let metadata = ResponseMetadata(
            statusCode: 200,
            headers: [
                "X-RateLimit-Limit": "5000",
                "X-RateLimit-Remaining": "4990",
                "X-RateLimit-Reset": "1700000000",
                "X-RateLimit-Resource": "core",
                "X-OAuth-Scopes": "repo, read:org, project",
                "GitHub-Authentication-Token-Expiration": "2026-11-30 12:00:00 UTC",
            ])
        #expect(metadata.rateLimit == RateLimit(limit: 5000, remaining: 4990, used: 10, reset: Date(timeIntervalSince1970: 1_700_000_000), resource: "core"))
        #expect(metadata.oauthScopes == [.repo, .readOrg, .project])
        #expect(metadata.tokenExpiration.map { Int($0.timeIntervalSince1970) } == 1_796_040_000)
    }
}
