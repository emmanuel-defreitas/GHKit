import Foundation
import Testing

@testable import GHKit

@Suite("Commits")
struct CommitsTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        _ = try decoder.decode([Commit].self, from: loadFixture("commit-items"))
        let comparison = try decoder.decode(CommitComparison.self, from: loadFixture("commit-comparison"))
        #expect(comparison.status == .behind)
        #expect(comparison.aheadBy == 1)
        #expect(comparison.commits.count == 1)

        let comment = try decoder.decode(CommitComment.self, from: loadFixture("commit-comment"))
        #expect(comment.authorAssociation == .collaborator)
        _ = try decoder.decode(CommitComment.self, from: loadFixture("commit-comment-2"))
        _ = try decoder.decode([CommitComment].self, from: loadFixture("commit-comment-items"))

        let combined = try decoder.decode(CombinedStatus.self, from: loadFixture("combined-commit-status"))
        #expect(combined.state == .success)
        #expect(combined.statuses.count == 2)
        let status = try decoder.decode(CommitStatus.self, from: loadFixture("status"))
        #expect(status.state == .success)
        _ = try decoder.decode([CommitStatus].self, from: loadFixture("status-items"))
    }

    @Test func commitRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.value(forHTTPHeaderField: "Accept") {
            case "application/vnd.github.diff": MockResponse(body: Data("diff --git a/x b/x".utf8))
            case "application/vnd.github.patch": MockResponse(body: Data("From abc".utf8))
            case "application/vnd.github.sha": MockResponse(body: Data("6dcb09b5\n".utf8))
            default:
                switch request.route {
                case "GET /repos/o/r/commits": .fixture("commit-items")
                case let route where route.hasPrefix("GET /repos/o/r/compare/"): .fixture("commit-comparison")
                default: .fixture("commit")
                }
            }
        }
        let repos = makeClient(transport).repositories
        let since = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await repos.commits("o", "r", ref: "dev", path: "Sources", author: "mona", since: since).collect()
        _ = try await repos.commit("release/v1", in: "o", "r")
        #expect(try await repos.commitDiff("abc", in: "o", "r") == "diff --git a/x b/x")
        #expect(try await repos.commitDiff("abc", in: "o", "r", format: .patch) == "From abc")
        #expect(try await repos.commitSHA(for: "main", in: "o", "r") == "6dcb09b5")
        _ = try await repos.compare("main", "octocat:feature/x", in: "o", "r")
        _ = try await repos.compareDiff("v1", "v2", in: "o", "r")

        #expect(
            transport.requests[0].queryItems == [
                "sha": "dev", "path": "Sources", "author": "mona", "since": "2023-11-14T22:13:20Z", "per_page": "100",
            ])
        #expect(
            transport.requests.map(\.path) == [
                "/repos/o/r/commits", "/repos/o/r/commits/release/v1", "/repos/o/r/commits/abc", "/repos/o/r/commits/abc",
                "/repos/o/r/commits/main", "/repos/o/r/compare/main...octocat:feature/x", "/repos/o/r/compare/v1...v2",
            ])
        #expect(transport.requests[6].value(forHTTPHeaderField: "Accept") == "application/vnd.github.diff")
    }

    @Test func commentRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/comments", "GET /repos/o/r/commits/abc/comments": .fixture("commit-comment-items")
            case "DELETE /repos/o/r/comments/1": .noContent()
            case "POST /repos/o/r/commits/abc/comments": .fixture("commit-comment", status: 201)
            default: .fixture("commit-comment-2")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.commitComments("o", "r").collect()
        _ = try await repos.comments(onCommit: "abc", in: "o", "r").collect()
        _ = try await repos.commitComment(id: 1, in: "o", "r")
        _ = try await repos.createCommitComment("Nice", on: "abc", in: "o", "r", path: "README.md", position: 4)
        _ = try await repos.updateCommitComment(id: 1, in: "o", "r", body: "Nicer")
        try await repos.deleteCommitComment(id: 1, in: "o", "r")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/comments", "GET /repos/o/r/commits/abc/comments", "GET /repos/o/r/comments/1",
                "POST /repos/o/r/commits/abc/comments", "PATCH /repos/o/r/comments/1", "DELETE /repos/o/r/comments/1",
            ])
        #expect(transport.requests[3].jsonBody == ["body": "Nice", "path": "README.md", "position": 4])
        #expect(transport.requests[4].jsonBody == ["body": "Nicer"])
    }

    @Test func statusRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/commits/main/statuses": .fixture("status-items")
            case "GET /repos/o/r/commits/main/status": .fixture("combined-commit-status")
            default: .fixture("status", status: 201)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.statuses(for: "main", in: "o", "r").collect()
        #expect(try await repos.combinedStatus(for: "main", in: "o", "r").state == .success)
        _ = try await repos.createStatus(
            NewCommitStatus(.failure, context: "ci/build", description: "2 tests failed", targetURL: URL(string: "https://ci.example.com/1")),
            on: "abc", in: "o", "r")
        #expect(transport.requests[2].route == "POST /repos/o/r/statuses/abc")
        #expect(
            transport.requests[2].jsonBody == [
                "state": "failure", "context": "ci/build", "description": "2 tests failed", "target_url": "https://ci.example.com/1",
            ])
    }
}
