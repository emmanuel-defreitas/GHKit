import Foundation
import MCP
import Testing

@testable import GHKit
@testable import GHKitMCP

@Suite("MCP pull request tools")
struct PullRequestToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "octocat", "repo": "Hello-World"]
    static let base = "/repos/octocat/Hello-World"
    static let pulls = "\(base)/pulls/1347"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let cases: [ToolRequestCase] = [
        .init(
            tool: "list_pull_requests", arguments: with(["state": "all", "base": "main", "sort": "long_running"]),
            response: .fixture("pull-request-simple-items"), route: "GET \(base)/pulls",
            query: ["state": "all", "base": "main", "sort": "long-running", "per_page": "30"]),
        .init(tool: "get_pull_request", arguments: with(["number": 1347]), response: .fixture("pull-request"), route: "GET \(pulls)"),
        .init(
            tool: "get_pull_request_diff", arguments: with(["number": 1347]), response: MockResponse(body: Data("diff --git a/x b/x".utf8)),
            route: "GET \(pulls)"),
        .init(
            tool: "list_pull_request_files", arguments: with(["number": 1347]), response: .fixture("diff-entry-items"),
            route: "GET \(pulls)/files", query: ["per_page": "30"]),
        .init(
            tool: "list_pull_request_commits", arguments: with(["number": 1347]), response: .fixture("commit-items"),
            route: "GET \(pulls)/commits", query: ["per_page": "30"]),
        .init(
            tool: "list_pull_request_reviews", arguments: with(["number": 1347]), response: .fixture("pull-request-review-items"),
            route: "GET \(pulls)/reviews", query: ["per_page": "30"]),
        .init(
            tool: "list_review_comments", arguments: with(["number": 1347]), response: .fixture("pull-request-review-comment-items"),
            route: "GET \(pulls)/comments", query: ["sort": "created", "per_page": "30"]),
        .init(
            tool: "get_requested_reviewers", arguments: with(["number": 1347]), response: .json(#"{"users": [], "teams": []}"#),
            route: "GET \(pulls)/requested_reviewers"),
        .init(
            tool: "list_pull_requests_for_commit", arguments: with(["sha": "abc"]), response: .fixture("pull-request-simple-items"),
            route: "GET \(base)/commits/abc/pulls", query: ["per_page": "30"]),
        .init(
            tool: "create_pull_request", arguments: with(["title": "Fix", "head": "octocat:fix", "base": "main", "draft": true]),
            response: .fixture("pull-request", status: 201), route: "POST \(base)/pulls",
            body: ["title": "Fix", "head": "octocat:fix", "base": "main", "draft": true]),
        .init(
            tool: "update_pull_request", arguments: with(["number": 1347, "state": "closed", "base": "dev"]),
            response: .fixture("pull-request"), route: "PATCH \(pulls)", body: ["state": "closed", "base": "dev"]),
        .init(
            tool: "merge_pull_request", arguments: with(["number": 1347, "method": "squash", "sha": "abc"]),
            response: .fixture("pull-request-merge-result-response-if-merge-was-successful"), route: "PUT \(pulls)/merge",
            body: ["merge_method": "squash", "sha": "abc"]),
        .init(
            tool: "update_pull_request_branch", arguments: with(["number": 1347, "sha": "abc"]),
            response: .json(#"{"message": "Updating pull request branch."}"#, status: 202), route: "PUT \(pulls)/update-branch",
            body: ["expected_head_sha": "abc"]),
        .init(
            tool: "request_reviewers", arguments: with(["number": 1347, "reviewers": ["hubot"], "teams": ["justice-league"]]),
            response: .fixture("pull-request-simple", status: 201), route: "POST \(pulls)/requested_reviewers",
            body: ["reviewers": ["hubot"], "team_reviewers": ["justice-league"]]),
        .init(
            tool: "create_review",
            arguments: with([
                "number": 1347, "event": "REQUEST_CHANGES", "body": "See notes",
                "comments": [["path": "a.swift", "line": 12, "body": "Rename"], ["path": "b.swift", "startLine": 3, "line": 5, "body": "Split"]],
            ]),
            response: .fixture("pull-request-review"), route: "POST \(pulls)/reviews",
            body: [
                "event": "REQUEST_CHANGES", "body": "See notes",
                "comments": [
                    ["path": "a.swift", "body": "Rename", "line": 12, "side": "RIGHT"],
                    ["path": "b.swift", "body": "Split", "start_line": 3, "start_side": "RIGHT", "line": 5, "side": "RIGHT"],
                ],
            ]),
        .init(
            tool: "add_review_comment",
            arguments: with(["number": 1347, "path": "a.swift", "line": 7, "side": "LEFT", "body": "Why?", "commitID": "abc"]),
            response: .fixture("pull-request-review-comment", status: 201), route: "POST \(pulls)/comments",
            body: ["body": "Why?", "path": "a.swift", "line": 7, "side": "LEFT", "commit_id": "abc"]),
        .init(
            tool: "reply_to_review_comment", arguments: with(["number": 1347, "commentID": 10, "body": "Done"]),
            response: .fixture("pull-request-review-comment", status: 201), route: "POST \(pulls)/comments/10/replies",
            body: ["body": "Done"]),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tools = Set(PullRequestTools.tools(for: .readWrite).map(\.name))
        let untested = tools.subtracting(Self.cases.map(\.tool))
        #expect(untested.isEmpty, "Untested: \(untested.sorted())")
    }

    @Test func returnsDiffsAsText() async throws {
        let (text, _) = try await callTool(
            "get_pull_request_diff", Self.with(["number": 1]), on: MockTransport(MockResponse(body: Data("diff --git a/x b/x".utf8))))
        #expect(text == "diff --git a/x b/x")
    }

    @Test func commentsOnTheHeadCommitByDefault() async throws {
        let pullRequest = try GitHubJSON.decoder().decode(PullRequest.self, from: loadFixture("pull-request"))
        let transport = MockTransport { _, index in index == 0 ? .fixture("pull-request") : .fixture("pull-request-review-comment", status: 201) }
        let (_, isError) = try await callTool(
            "add_review_comment", Self.with(["number": 1347, "path": "README.md", "body": "Typo"]), on: transport)
        #expect(!isError)
        #expect(transport.requests.map(\.route) == ["GET \(Self.pulls)", "POST \(Self.pulls)/comments"])
        #expect(
            transport.requests[1].jsonBody == ["body": "Typo", "path": "README.md", "subject_type": "file", "commit_id": .string(pullRequest.head.sha)])
    }

    @Test func rejectsEmptyReviewRequestsAndBackwardRanges() async throws {
        let transport = MockTransport(.json("{}"))
        let (_, emptyError) = try await callTool("request_reviewers", Self.with(["number": 1]), on: transport)
        #expect(emptyError)
        let (text, rangeError) = try await callTool(
            "add_review_comment", Self.with(["number": 1, "path": "a", "body": "b", "line": 3, "startLine": 9, "commitID": "c"]), on: transport)
        #expect(rangeError)
        #expect(text == "`startLine` must come before `line`.")
        #expect(transport.requests.isEmpty)
    }

    @Test func emptyBodyClearsTheDescription() async throws {
        let transport = MockTransport(.fixture("pull-request"))
        let (text, isError) = try await callTool("update_pull_request", Self.with(["number": 1347, "body": ""]), on: transport)
        #expect(!isError, "\(text)")
        #expect(transport.requests.first?.jsonBody == ["body": ""])
    }
}
