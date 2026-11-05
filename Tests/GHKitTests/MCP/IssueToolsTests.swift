import Foundation
import MCP
import Testing

@testable import GHKitActivity
@testable import GHKitApps
@testable import GHKitCore
@testable import GHKitGists
@testable import GHKitIssues
@testable import GHKitMCP
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitPullRequests
@testable import GHKitRepositories
@testable import GHKitSearch
@testable import GHKitUsers

@Suite("MCP issue tools")
struct IssueToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "octocat", "repo": "Hello-World"]
    static let base = "/repos/octocat/Hello-World"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let cases: [ToolRequestCase] = [
        .init(
            tool: "list_issues",
            arguments: with([
                "state": "closed", "labels": ["bug", "ui"], "assignee": "none", "milestone": "3", "creator": "octocat",
                "sort": "updated", "perPage": 10,
            ]),
            response: .fixture("issue-items"), route: "GET \(base)/issues",
            query: [
                "state": "closed", "labels": "bug,ui", "assignee": "none", "milestone": "3", "creator": "octocat",
                "sort": "updated", "per_page": "10",
            ]),
        .init(
            tool: "list_issues", arguments: ["relationship": "mentioned", "since": "2026-01-31"], response: .fixture("issue-with-repo-items"),
            route: "GET /issues",
            query: ["filter": "mentioned", "state": "open", "since": "2026-01-31T00:00:00Z", "sort": "created", "per_page": "30"]),
        .init(
            tool: "list_issues", arguments: ["org": "github"], response: .fixture("issue-with-repo-items"), route: "GET /orgs/github/issues",
            query: ["filter": "assigned", "state": "open", "sort": "created", "per_page": "30"]),
        .init(tool: "get_issue", arguments: with(["number": 1347]), response: .fixture("issue"), route: "GET \(base)/issues/1347"),
        .init(
            tool: "list_issue_comments", arguments: with(["number": 1347]), response: .fixture("issue-comment-items"),
            route: "GET \(base)/issues/1347/comments", query: ["per_page": "30"]),
        .init(
            tool: "get_issue_timeline", arguments: with(["number": 1347]), response: .fixture("timeline-issue-events"),
            route: "GET \(base)/issues/1347/timeline", query: ["per_page": "30"]),
        .init(
            tool: "list_sub_issues", arguments: with(["number": 1347]), response: .fixture("issue-items"),
            route: "GET \(base)/issues/1347/sub_issues", query: ["per_page": "30"]),
        .init(tool: "list_labels", arguments: repo, response: .fixture("label-items"), route: "GET \(base)/labels", query: ["per_page": "30"]),
        .init(
            tool: "list_milestones", arguments: with(["state": "all"]), response: .fixture("milestone-items"), route: "GET \(base)/milestones",
            query: ["state": "all", "sort": "due_on", "per_page": "30"]),
        .init(
            tool: "list_assignees", arguments: repo, response: .fixture("simple-user-items"), route: "GET \(base)/assignees",
            query: ["per_page": "30"]),
        .init(tool: "list_issue_types", arguments: repo, response: .fixture("issue-type-items"), route: "GET \(base)/issue-types"),
        .init(
            tool: "create_issue", arguments: with(["title": "Crash", "body": "Steps", "labels": ["bug"], "milestone": 2, "type": "Bug"]),
            response: .fixture("issue", status: 201), route: "POST \(base)/issues",
            body: ["title": "Crash", "body": "Steps", "labels": ["bug"], "milestone": 2, "type": "Bug"]),
        .init(
            tool: "update_issue", arguments: with(["number": 1347, "state": "closed", "stateReason": "not_planned", "removeMilestone": true]),
            response: .fixture("issue"), route: "PATCH \(base)/issues/1347",
            body: ["state": "closed", "state_reason": "not_planned", "milestone": nil]),
        .init(
            tool: "add_issue_comment", arguments: with(["number": 1347, "body": "Thanks!"]), response: .fixture("issue-comment", status: 201),
            route: "POST \(base)/issues/1347/comments", body: ["body": "Thanks!"]),
        .init(
            tool: "update_issue_comment", arguments: with(["commentID": 1, "body": "Edited"]), response: .fixture("issue-comment"),
            route: "PATCH \(base)/issues/comments/1", body: ["body": "Edited"]),
        .init(
            tool: "delete_issue_comment", arguments: with(["commentID": 1]), response: .noContent(),
            route: "DELETE \(base)/issues/comments/1"),
        .init(
            tool: "add_labels", arguments: with(["number": 1347, "labels": ["bug"]]), response: .fixture("label-items"),
            route: "POST \(base)/issues/1347/labels", body: ["labels": ["bug"]]),
        .init(
            tool: "remove_label", arguments: with(["number": 1347, "label": "help wanted"]), response: .fixture("label-items"),
            route: "DELETE \(base)/issues/1347/labels/help%20wanted"),
        .init(
            tool: "add_assignees", arguments: with(["number": 1347, "assignees": ["hubot"]]), response: .fixture("issue", status: 201),
            route: "POST \(base)/issues/1347/assignees", body: ["assignees": ["hubot"]]),
        .init(
            tool: "remove_assignees", arguments: with(["number": 1347, "assignees": ["hubot"]]), response: .fixture("issue"),
            route: "DELETE \(base)/issues/1347/assignees", body: ["assignees": ["hubot"]]),
        .init(
            tool: "create_label", arguments: with(["name": "bug", "color": "f29513"]), response: .fixture("label", status: 201),
            route: "POST \(base)/labels", body: ["name": "bug", "color": "f29513"]),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tested = Set(Self.cases.map(\.tool) + ["add_sub_issue"])
        let tools = Set(IssueTools.tools(for: .readWrite).map(\.name))
        #expect(tools.subtracting(tested).isEmpty, "Untested: \(tools.subtracting(tested).sorted())")
    }

    @Test func addsSubIssuesByNumber() async throws {
        let issue = try GitHubJSON.decoder().decode(GitHubIssue.self, from: loadFixture("issue"))
        let transport = MockTransport(.fixture("issue"))
        let (_, isError) = try await callTool("add_sub_issue", Self.with(["number": 1, "subIssue": 1347]), on: transport)
        #expect(!isError)
        #expect(transport.requests.map(\.route) == ["GET \(Self.base)/issues/1347", "POST \(Self.base)/issues/1/sub_issues"])
        #expect(transport.requests[1].jsonBody == ["sub_issue_id": .number(Double(issue.id))])
    }

    @Test func rejectsBadMilestoneFilters() async throws {
        let transport = MockTransport(.json("[]"))
        let (text, isError) = try await callTool("list_issues", Self.with(["milestone": "v1"]), on: transport)
        #expect(isError)
        #expect(text == "`milestone` must be a number, `*`, or `none`.")
        #expect(transport.requests.isEmpty)
    }

    @Test func listsUseTheDomainCredential() async throws {
        let transport = MockTransport(.fixture("issue-items"))
        let client = makeClient(transport, authenticator: .routed(default: .token("main"), domains: [.issues: .token("issues")]))
        let toolbox = GitHubToolbox(client: client, toolsets: .all, access: .readOnly)
        let result = try #require(await toolbox.call(CallTool.Parameters(name: "list_issues", arguments: Self.repo)))
        #expect(result.isError != true)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer issues")
    }

    @Test func emptyBodyClearsTheDescription() async throws {
        let transport = MockTransport(.fixture("issue"))
        let (text, isError) = try await callTool("update_issue", Self.with(["number": 1347, "body": ""]), on: transport)
        #expect(!isError, "\(text)")
        #expect(transport.requests.first?.jsonBody == ["body": ""])
    }
}
