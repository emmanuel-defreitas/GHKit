import Foundation
import Testing

@testable import GHKit

@Suite("Repository statistics")
struct RepositoryStatisticsTests {
    let decoder = GitHubJSON.decoder()

    @Test func trafficRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/traffic/views": .fixture("view-traffic")
            case "GET /repos/o/r/traffic/clones": .fixture("clone-traffic")
            case "GET /repos/o/r/traffic/popular/paths": .fixture("content-traffic-items")
            default: .fixture("referrer-traffic-items")
            }
        }
        let repos = makeClient(transport).repositories
        let views = try await repos.views("o", "r", per: .week)
        let clones = try await repos.clones("o", "r")
        let content = try await repos.popularContent("o", "r")
        let referrers = try await repos.referrers("o", "r")

        #expect(views.count == 14_850)
        #expect(views.breakdown.count == 15)
        #expect(clones.breakdown.first?.count == 2)
        #expect(content.first?.title.isEmpty == false)
        #expect(referrers.first?.referrer == "Google")
        #expect(transport.requests[0].queryItems == ["per": "week"])
        #expect(transport.requests[1].queryItems == ["per": "day"])
        #expect(transport.requests[3].route == "GET /repos/o/r/traffic/popular/referrers")
    }

    @Test func statisticsDecode() throws {
        let frequency = try decoder.decode([WeeklyCodeFrequency].self, from: loadFixture("code-frequency-stat-items"))
        #expect(frequency.first?.week == Date(timeIntervalSince1970: 1_302_998_400))
        #expect(frequency.first?.additions == 1124)
        #expect(frequency.first?.deletions == 435)
        let negative = try decoder.decode(WeeklyCodeFrequency.self, from: Data("[1,2,-3]".utf8))
        #expect(negative.deletions == 3)

        let activity = try decoder.decode([WeeklyCommitActivity].self, from: loadFixture("commit-activity-items"))
        #expect(activity.first?.days.count == 7)
        let contributors = try decoder.decode([ContributorStatistics].self, from: loadFixture("contributor-activity-items"))
        #expect(contributors.first?.author?.login == "octocat")
        #expect(contributors.first?.weeks.first?.additions == 6898)
        #expect(contributors.first?.weeks.first?.commits == 10)
        let participation = try decoder.decode(ParticipationStatistics.self, from: loadFixture("participation-stats"))
        #expect(participation.all.count == 52)
        let punchCard = try decoder.decode([PunchCardHour].self, from: loadFixture("code-frequency-stat-items-2"))
        #expect(punchCard[1].hour == 1)
        #expect(punchCard[1].commits == 43)
    }

    @Test func statisticsRequests() async throws {
        let transport = MockTransport { request, index in
            switch (request.route, index) {
            case (_, 0): .json("{}", status: 202)
            case (_, 1): .noContent()
            case ("GET /repos/o/r/stats/code_frequency", _): .fixture("code-frequency-stat-items")
            case ("GET /repos/o/r/stats/commit_activity", _): .fixture("commit-activity-items")
            case ("GET /repos/o/r/stats/contributors", _): .fixture("contributor-activity-items")
            case ("GET /repos/o/r/stats/participation", _): .fixture("participation-stats")
            default: .fixture("code-frequency-stat-items-2")
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.codeFrequency("o", "r") == nil)
        #expect(try await repos.codeFrequency("o", "r") == [])
        #expect(try await repos.codeFrequency("o", "r")?.isEmpty == false)
        #expect(try await repos.commitActivity("o", "r")?.isEmpty == false)
        #expect(try await repos.contributorStatistics("o", "r")?.count == 1)
        #expect(try await repos.participation("o", "r")?.owner.count == 52)
        #expect(try await repos.punchCard("o", "r")?.count == 3)
        #expect(
            transport.requests.map(\.path) == [
                "/repos/o/r/stats/code_frequency", "/repos/o/r/stats/code_frequency", "/repos/o/r/stats/code_frequency",
                "/repos/o/r/stats/commit_activity", "/repos/o/r/stats/contributors", "/repos/o/r/stats/participation",
                "/repos/o/r/stats/punch_card",
            ])
    }

    @Test func statisticsDecodingFailureIsReported() async throws {
        let repos = makeClient(MockTransport(.json(#"{"unexpected":true}"#))).repositories
        await #expect(throws: GitHubError.self) { try await repos.punchCard("o", "r") }
    }
}
