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

/// Calls one tool against canned responses and returns the result text.
func callTool(
    _ name: String,
    _ arguments: [String: MCP.Value] = [:],
    on transport: MockTransport,
    toolsets: Set<GitHubToolset> = .all,
    access: GitHubToolAccess = .readWrite
) async throws -> (text: String, isError: Bool) {
    let toolbox = GitHubToolbox(client: makeClient(transport), toolsets: toolsets, access: access)
    let result = try #require(await toolbox.call(CallTool.Parameters(name: name, arguments: arguments)), "No tool named \(name)")
    guard case .text(let text, _, _)? = result.content.first else { return ("", true) }
    return (text, result.isError ?? false)
}

/// One tool call and the request it should send.
struct ToolRequestCase: Sendable, CustomTestStringConvertible {
    var tool: String
    var arguments: [String: MCP.Value]
    var response: MockResponse
    var route: String
    var query: [String: String] = [:]
    var body: JSONValue? = nil

    var testDescription: String { tool }

    func check() async throws {
        let transport = MockTransport(response)
        let (text, isError) = try await callTool(tool, arguments, on: transport)
        #expect(!isError, "\(tool) failed: \(text)")
        #expect(transport.requests.map(\.route) == [route])
        #expect(transport.requests.first?.queryItems == query)
        if let body { #expect(transport.requests.first?.jsonBody == body) }
    }
}

@Suite("MCP repository tools")
struct RepositoryToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "octocat", "repo": "Hello-World"]
    static let base = "/repos/octocat/Hello-World"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let reads: [ToolRequestCase] = [
        .init(tool: "get_repository", arguments: repo, response: .fixture("full-repository"), route: "GET \(base)"),
        .init(
            tool: "list_repositories", arguments: ["sort": "updated", "perPage": 5], response: .fixture("repository-items"),
            route: "GET /user/repos",
            query: ["sort": "updated", "per_page": "5", "affiliation": "owner,collaborator,organization_member"]),
        .init(
            tool: "list_repositories", arguments: ["user": "octocat"], response: .fixture("minimal-repository-items"),
            route: "GET /users/octocat/repos", query: ["type": "owner", "sort": "full_name", "per_page": "30"]),
        .init(
            tool: "list_repositories", arguments: ["org": "github"], response: .fixture("minimal-repository-items"),
            route: "GET /orgs/github/repos", query: ["type": "all", "sort": "created", "per_page": "30"]),
        .init(tool: "get_repository_languages", arguments: repo, response: .fixture("language"), route: "GET \(base)/languages"),
        .init(
            tool: "list_contributors", arguments: repo, response: .fixture("contributor-items"), route: "GET \(base)/contributors",
            query: ["per_page": "30"]),
        .init(
            tool: "list_forks", arguments: with(["sort": "stargazers"]), response: .fixture("minimal-repository-items"),
            route: "GET \(base)/forks", query: ["sort": "stargazers", "per_page": "30"]),
        .init(
            tool: "get_file_contents", arguments: with(["path": "lib", "ref": "main"]), response: .fixture("content-directory"),
            route: "GET \(base)/contents/lib", query: ["ref": "main"]),
        .init(tool: "get_readme", arguments: repo, response: .fixture("content-file"), route: "GET \(base)/readme"),
        .init(
            tool: "list_branches", arguments: with(["protected": true]), response: .fixture("short-branch-with-protection-items"),
            route: "GET \(base)/branches", query: ["protected": "true", "per_page": "30"]),
        .init(
            tool: "get_branch", arguments: with(["branch": "release/v1"]), response: .fixture("branch-with-protection"),
            route: "GET \(base)/branches/release%2Fv1"),
        .init(tool: "list_tags", arguments: repo, response: .fixture("tag-items"), route: "GET \(base)/tags", query: ["per_page": "30"]),
        .init(
            tool: "list_commits",
            arguments: with(["ref": "main", "path": "README.md", "author": "octocat", "since": "2026-01-31"]),
            response: .fixture("commit-items"), route: "GET \(base)/commits",
            query: ["sha": "main", "path": "README.md", "author": "octocat", "since": "2026-01-31T00:00:00Z", "per_page": "30"]),
        .init(tool: "get_commit", arguments: with(["ref": "abc123"]), response: .fixture("commit"), route: "GET \(base)/commits/abc123"),
        .init(
            tool: "compare_commits", arguments: with(["base": "main", "head": "feature"]), response: .fixture("commit-comparison"),
            route: "GET \(base)/compare/main...feature"),
        .init(
            tool: "get_commit_status", arguments: with(["ref": "main"]), response: .fixture("combined-commit-status"),
            route: "GET \(base)/commits/main/status", query: ["per_page": "100"]),
        .init(tool: "list_releases", arguments: repo, response: .fixture("release-items"), route: "GET \(base)/releases", query: ["per_page": "30"]),
        .init(tool: "get_release", arguments: repo, response: .fixture("release"), route: "GET \(base)/releases/latest"),
        .init(tool: "get_release", arguments: with(["tag": "v1.0.0"]), response: .fixture("release"), route: "GET \(base)/releases/tags/v1.0.0"),
        .init(tool: "get_release", arguments: with(["id": 1]), response: .fixture("release"), route: "GET \(base)/releases/1"),
        .init(
            tool: "generate_release_notes", arguments: with(["tag": "v1.1.0", "previousTag": "v1.0.0"]),
            response: .fixture("release-notes-content"), route: "POST \(base)/releases/generate-notes",
            body: ["tag_name": "v1.1.0", "previous_tag_name": "v1.0.0"]),
    ]

    static let writes: [ToolRequestCase] = [
        .init(
            tool: "create_repository", arguments: ["name": "app", "private": true, "autoInit": true],
            response: .fixture("full-repository", status: 201), route: "POST /user/repos",
            body: ["name": "app", "private": true, "visibility": "private", "auto_init": true]),
        .init(
            tool: "create_repository", arguments: ["name": "app", "org": "github"], response: .fixture("full-repository", status: 201),
            route: "POST /orgs/github/repos", body: ["name": "app"]),
        .init(
            tool: "update_repository", arguments: with(["description": "New", "archived": true]), response: .fixture("full-repository"),
            route: "PATCH \(base)", body: ["description": "New", "archived": true]),
        .init(
            tool: "fork_repository", arguments: with(["org": "github", "defaultBranchOnly": true]),
            response: .fixture("full-repository", status: 202), route: "POST \(base)/forks",
            body: ["organization": "github", "default_branch_only": true]),
        .init(
            tool: "replace_topics", arguments: with(["topics": ["swift", "github"]]), response: .json(#"{"names": ["swift", "github"]}"#),
            route: "PUT \(base)/topics", body: ["names": ["swift", "github"]]),
        .init(
            tool: "create_or_update_file",
            arguments: with(["path": "docs/a b.md", "content": "hello world", "message": "Add docs", "branch": "main", "sha": "abc"]),
            response: .fixture("file-commit"), route: "PUT \(base)/contents/docs/a%20b.md",
            body: ["message": "Add docs", "content": "aGVsbG8gd29ybGQ=", "branch": "main", "sha": "abc"]),
        .init(
            tool: "delete_file", arguments: with(["path": "README.md", "sha": "abc", "message": "Remove"]),
            response: .fixture("file-commit"),
            route: "DELETE \(base)/contents/README.md", body: ["message": "Remove", "sha": "abc"]),
        .init(
            tool: "merge_branch", arguments: with(["base": "main", "head": "feature", "message": "Merge"]),
            response: .fixture("commit", status: 201), route: "POST \(base)/merges",
            body: ["base": "main", "head": "feature", "commit_message": "Merge"]),
        .init(
            tool: "create_release", arguments: with(["tag": "v1.0.0", "name": "One", "draft": true, "generateNotes": true]),
            response: .fixture("release", status: 201), route: "POST \(base)/releases",
            body: ["tag_name": "v1.0.0", "name": "One", "draft": true, "generate_release_notes": true]),
        .init(
            tool: "update_release", arguments: with(["id": 1, "draft": false]), response: .fixture("release"),
            route: "PATCH \(base)/releases/1", body: ["draft": false]),
        .init(tool: "delete_release", arguments: with(["id": 1]), response: .noContent(), route: "DELETE \(base)/releases/1"),
    ]

    @Test(arguments: reads) func readToolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test(arguments: writes) func writeToolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tested = Set((Self.reads + Self.writes).map(\.tool))
        let tools = Set(RepositoryTools.tools(for: .readWrite).map(\.name))
        #expect(tools.subtracting(tested).isEmpty, "Untested: \(tools.subtracting(tested).sorted())")
    }

    @Test func writeToolsAreHiddenWhenReadOnly() {
        let readOnly = Set(GitHubToolbox(client: makeClient(MockTransport(.noContent())), toolsets: [.repositories]).tools.map(\.name))
        #expect(readOnly.contains("get_file_contents"))
        #expect(readOnly.contains("generate_release_notes"))
        #expect(!readOnly.contains("create_or_update_file"))
        #expect(!readOnly.contains("delete_release"))
    }

    // MARK: Results

    @Test func returnsFilesAsText() async throws {
        let file = #"{"type": "file", "name": "a.txt", "path": "a.txt", "sha": "s1", "size": 11, "encoding": "base64", "content": "aGVsbG8g\nd29ybGQ="}"#
        let (text, _) = try await callTool("get_file_contents", Self.with(["path": "a.txt"]), on: MockTransport(.json(file)))
        let view = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        #expect(view == ["type": "file", "path": "a.txt", "sha": "s1", "size": 11, "text": "hello world"])
    }

    @Test func explainsMissingText() async throws {
        let binary = #"{"type": "file", "name": "a.png", "path": "a.png", "sha": "s", "size": 3, "encoding": "base64", "content": "/wD+"}"#
        let (text, _) = try await callTool("get_file_contents", Self.with(["path": "a.png"]), on: MockTransport(.json(binary)))
        #expect(text.contains("binary"))
        let large = #"{"type": "file", "name": "big", "path": "big", "sha": "s", "size": 2000000, "encoding": "none", "content": ""}"#
        let (note, _) = try await callTool("get_file_contents", Self.with(["path": "big"]), on: MockTransport(.json(large)))
        #expect(note.contains("too large"))
    }

    @Test func listsDirectoriesWithoutLinks() async throws {
        let (text, _) = try await callTool("get_file_contents", Self.repo, on: MockTransport(.fixture("content-directory")))
        let view = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        #expect(view["entries"]?[0]?["path"] == "lib/octokit.rb")
        #expect(view["entries"]?[0]?["url"] == nil)
    }

    @Test func summarizesFileCommits() async throws {
        let (text, _) = try await callTool(
            "create_or_update_file", Self.with(["path": "README.md", "content": "x", "message": "m"]), on: MockTransport(.fixture("file-commit")))
        let view = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        #expect(view["commit_sha"] == "7638417db6d59f3c431d3e1f261cc637155684cd")
        #expect(view["sha"] == "95b966ae1c166bd92f8ae7d1c313e738c731dfc3")
    }

    @Test func reportsMergesWithNothingToDo() async throws {
        let (text, isError) = try await callTool(
            "merge_branch", Self.with(["base": "main", "head": "main"]), on: MockTransport(.noContent()))
        #expect(!isError)
        #expect(text == "Nothing to merge: `main` already contains `main`.")
    }

    @Test func rejectsBadChoicesAndConflicts() async throws {
        let transport = MockTransport(.json("[]"))
        let (sort, sortError) = try await callTool("list_repositories", ["sort": "stars"], on: transport)
        #expect(sortError)
        #expect(sort == "`sort` must be one of: full_name, created, updated, pushed.")
        let (_, bothError) = try await callTool("list_repositories", ["user": "a", "org": "b"], on: transport)
        #expect(bothError)
        let (date, dateError) = try await callTool("list_commits", Self.with(["since": "yesterday"]), on: transport)
        #expect(dateError)
        #expect(date.contains("ISO 8601"))
        #expect(transport.requests.isEmpty)
    }

    @Test func emptyStringsClearFields() async throws {
        let repository = MockTransport(.fixture("full-repository"))
        _ = try await callTool("update_repository", Self.with(["description": "", "homepage": ""]), on: repository)
        #expect(repository.requests.first?.jsonBody == ["description": "", "homepage": ""])

        let release = MockTransport(.fixture("release"))
        _ = try await callTool("update_release", Self.with(["id": 1, "body": ""]), on: release)
        #expect(release.requests.first?.jsonBody == ["body": ""])
    }

    @Test func requiresContentAndTopics() async throws {
        let transport = MockTransport(.json("{}"))
        let (file, fileError) = try await callTool(
            "create_or_update_file", Self.with(["path": "a.md", "message": "Edit", "sha": "abc"]), on: transport)
        #expect(fileError)
        #expect(file == "Missing required argument `content`.")
        let (topics, topicsError) = try await callTool("replace_topics", Self.repo, on: transport)
        #expect(topicsError)
        #expect(topics == "Missing required argument `topics`.")
        #expect(transport.requests.isEmpty)
    }
}
