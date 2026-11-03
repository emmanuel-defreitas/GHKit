import Foundation
import MCP
import Testing

@testable import GHKit
@testable import GHKitMCP

@Suite("MCP search, activity, gist, and reaction tools")
struct SearchAndActivityToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "octocat", "repo": "Hello-World"]
    static let base = "/repos/octocat/Hello-World"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let cases: [ToolRequestCase] = [
        // Search
        .init(
            tool: "search_code", arguments: ["query": "addClass repo:jquery/jquery"], response: .fixture("code-search-result-item-paginated"),
            route: "GET /search/code", query: ["q": "addClass repo:jquery/jquery", "per_page": "30"]),
        .init(
            tool: "search_issues", arguments: ["query": "is:pr is:open", "sort": "updated"],
            response: .fixture("issue-search-result-item-paginated"), route: "GET /search/issues",
            query: ["q": "is:pr is:open", "sort": "updated", "per_page": "30"]),
        .init(
            tool: "search_repositories", arguments: ["query": "swift", "sort": "help_wanted_issues", "perPage": 5],
            response: .fixture("repo-search-result-item-paginated"), route: "GET /search/repositories",
            query: ["q": "swift", "sort": "help-wanted-issues", "per_page": "5"]),
        .init(
            tool: "search_users", arguments: ["query": "tom", "sort": "followers"], response: .fixture("user-search-result-item-paginated"),
            route: "GET /search/users", query: ["q": "tom", "sort": "followers", "per_page": "30"]),
        .init(
            tool: "search_commits", arguments: ["query": "fix", "sort": "author_date"], response: .fixture("commit-search-result-item-paginated"),
            route: "GET /search/commits", query: ["q": "fix", "sort": "author-date", "per_page": "30"]),
        // Activity
        .init(
            tool: "list_notifications", arguments: ["all": true, "since": "2026-01-31"], response: .fixture("thread-items"),
            route: "GET /notifications", query: ["all": "true", "since": "2026-01-31T00:00:00Z", "per_page": "30"]),
        .init(
            tool: "list_notifications", arguments: with(["participating": true]), response: .fixture("thread-items"),
            route: "GET \(base)/notifications", query: ["participating": "true", "per_page": "30"]),
        .init(
            tool: "list_events", arguments: ["user": "octocat", "received": true], response: .fixture("user-received-events-items"),
            route: "GET /users/octocat/received_events", query: ["per_page": "30"]),
        .init(
            tool: "list_events", arguments: repo, response: .fixture("user-events-items"), route: "GET \(base)/events",
            query: ["per_page": "30"]),
        .init(
            tool: "list_starred_repositories", arguments: ["user": "octocat"], response: .fixture("repository-items"),
            route: "GET /users/octocat/starred", query: ["sort": "created", "per_page": "30"]),
        .init(tool: "mark_notifications_read", arguments: [:], response: .noContent(), route: "PUT /notifications"),
        .init(tool: "mark_notification_done", arguments: ["threadID": "1"], response: .noContent(), route: "DELETE /notifications/threads/1"),
        .init(tool: "star_repository", arguments: repo, response: .noContent(), route: "PUT /user/starred/octocat/Hello-World"),
        .init(tool: "unstar_repository", arguments: repo, response: .noContent(), route: "DELETE /user/starred/octocat/Hello-World"),
        // Gists
        .init(
            tool: "list_gists", arguments: ["starred": true], response: .fixture("base-gist-items"), route: "GET /gists/starred",
            query: ["per_page": "30"]),
        .init(tool: "get_gist", arguments: ["id": "aa5a315d", "revision": "57a7f021"], response: .fixture("gist"), route: "GET /gists/aa5a315d/57a7f021"),
        .init(
            tool: "create_gist", arguments: ["files": ["notes.md": "# Notes"], "description": "Notes", "public": true],
            response: .fixture("gist", status: 201), route: "POST /gists",
            body: ["files": ["notes.md": ["content": "# Notes"]], "description": "Notes", "public": true]),
        .init(
            tool: "update_gist", arguments: ["id": "aa5a315d", "files": ["a.md": "new", "old.md": nil]], response: .fixture("gist"),
            route: "PATCH /gists/aa5a315d", body: ["files": ["a.md": ["content": "new"], "old.md": nil]]),
        .init(tool: "delete_gist", arguments: ["id": "aa5a315d"], response: .noContent(), route: "DELETE /gists/aa5a315d"),
        // Reactions
        .init(
            tool: "list_reactions", arguments: with(["subject": "issue_comment", "id": 9, "content": "heart"]),
            response: .fixture("reaction-items"), route: "GET \(base)/issues/comments/9/reactions",
            query: ["content": "heart", "per_page": "30"]),
        .init(
            tool: "add_reaction", arguments: with(["subject": "issue", "id": 1347, "content": "+1"]), response: .fixture("reaction", status: 201),
            route: "POST \(base)/issues/1347/reactions", body: ["content": "+1"]),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tools = [SearchTools.tools, ActivityTools.tools, GistTools.tools, ReactionTools.tools]
            .flatMap { $0(.readWrite) }.map(\.name)
        let untested = Set(tools).subtracting(Self.cases.map(\.tool))
        #expect(untested.isEmpty, "Untested: \(untested.sorted())")
    }

    @Test func searchToolsListOnlyTheirOwnSorts() async throws {
        let tools = SearchTools.tools(for: .readOnly)
        let code = try #require(tools.first { $0.name == "search_code" })
        #expect(code.schema.objectValue?["properties"]?.objectValue?["sort"] == nil)
        let (text, isError) = try await callTool("search_users", ["query": "a", "sort": "stars"], on: MockTransport(.json("{}")))
        #expect(isError)
        #expect(text == "`sort` must be one of: followers, repositories, joined.")
    }

    @Test func rejectsAmbiguousSources() async throws {
        let transport = MockTransport(.json("[]"))
        #expect(try await callTool("list_events", ["user": "a", "org": "b"], on: transport).isError)
        #expect(try await callTool("list_events", [:], on: transport).isError)
        #expect(try await callTool("list_notifications", ["owner": "a"], on: transport).isError)
        #expect(try await callTool("list_gists", ["user": "a", "starred": true], on: transport).isError)
        #expect(try await callTool("create_gist", ["files": [:]], on: transport).isError)
        #expect(try await callTool("list_reactions", Self.with(["subject": "wiki", "id": 1]), on: transport).isError)
        #expect(transport.requests.isEmpty)
    }

}
