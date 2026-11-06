import Foundation
import MCP
import Testing

@testable import GHKitCore
@testable import GHKitMCP
@testable import GHKitMeta
@testable import GHKitRepositories

@Suite("MCP Git and meta tools")
struct GitAndMetaToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "o", "repo": "r"]
    static let base = "/repos/o/r/git"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let html = MockResponse(body: Data("<p>Hi</p>".utf8))

    static let cases: [ToolRequestCase] = [
        // Git
        .init(
            tool: "get_git_tree", arguments: with(["sha": "main", "recursive": true]), response: .fixture("git-tree-default-response"),
            route: "GET \(base)/trees/main", query: ["recursive": "1"]),
        .init(tool: "get_git_blob", arguments: with(["sha": "abc"]), response: .fixture("blob"), route: "GET \(base)/blobs/abc"),
        .init(tool: "get_git_commit", arguments: with(["sha": "abc"]), response: .fixture("git-commit-2"), route: "GET \(base)/commits/abc"),
        .init(tool: "get_git_ref", arguments: with(["ref": "heads/main"]), response: .fixture("git-ref"), route: "GET \(base)/ref/heads/main"),
        .init(
            tool: "list_git_refs", arguments: with(["prefix": "tags"]), response: .fixture("git-ref-items"), route: "GET \(base)/matching-refs/tags"),
        .init(tool: "get_git_tag", arguments: with(["sha": "abc"]), response: .fixture("git-tag"), route: "GET \(base)/tags/abc"),
        .init(
            tool: "create_git_tree",
            arguments: with([
                "base": "t0",
                "entries": [
                    ["path": "README.md", "content": "Hello"], ["path": "run.sh", "sha": "b1", "mode": "executable"],
                    ["path": "vendor", "sha": "c1", "mode": "submodule"], ["path": "old.txt", "delete": true],
                ],
            ]),
            response: .fixture("git-tree", status: 201), route: "POST \(base)/trees",
            body: [
                "base_tree": "t0",
                "tree": [
                    ["path": "README.md", "mode": "100644", "type": "blob", "content": "Hello"],
                    ["path": "run.sh", "mode": "100755", "type": "blob", "sha": "b1"],
                    ["path": "vendor", "mode": "160000", "type": "commit", "sha": "c1"],
                    ["path": "old.txt", "mode": "100644", "type": "blob", "sha": nil],
                ],
            ]),
        .init(
            tool: "create_git_blob", arguments: with(["content": "aGk=", "base64": true]), response: .fixture("short-blob", status: 201),
            route: "POST \(base)/blobs", body: ["content": "aGk=", "encoding": "base64"]),
        .init(
            tool: "create_git_commit", arguments: with(["message": "Update", "tree": "t1", "parents": ["p1"]]),
            response: .fixture("git-commit", status: 201), route: "POST \(base)/commits",
            body: ["message": "Update", "tree": "t1", "parents": ["p1"]]),
        .init(
            tool: "create_git_ref", arguments: with(["ref": "heads/feature", "sha": "c1"]), response: .fixture("git-ref", status: 201),
            route: "POST \(base)/refs", body: ["ref": "refs/heads/feature", "sha": "c1"]),
        .init(
            tool: "update_git_ref", arguments: with(["ref": "heads/main", "sha": "c2"]), response: .fixture("git-ref"),
            route: "PATCH \(base)/refs/heads/main", body: ["sha": "c2", "force": false]),
        .init(tool: "delete_git_ref", arguments: with(["ref": "heads/old"]), response: .noContent(), route: "DELETE \(base)/refs/heads/old"),
        .init(
            tool: "create_git_tag", arguments: with(["tag": "v1.0", "message": "First", "sha": "c1"]), response: .fixture("git-tag", status: 201),
            route: "POST \(base)/tags", body: ["tag": "v1.0", "message": "First", "object": "c1", "type": "commit"]),
        // Meta
        .init(
            tool: "render_markdown", arguments: ["text": "Fixes #1", "mode": "gfm", "owner": "o", "repo": "r"], response: html,
            route: "POST /markdown", body: ["text": "Fixes #1", "mode": "gfm", "context": "o/r"]),
        .init(
            tool: "list_licenses", arguments: ["featured": true], response: .fixture("license-simple-items"), route: "GET /licenses",
            query: ["featured": "true", "per_page": "30"]),
        .init(tool: "get_license", arguments: ["key": "mit"], response: .fixture("license"), route: "GET /licenses/mit"),
        .init(tool: "list_gitignore_templates", arguments: [:], response: .json(#"["C","Swift"]"#), route: "GET /gitignore/templates"),
        .init(
            tool: "get_gitignore_template", arguments: ["name": "Swift"], response: .fixture("gitignore-template"),
            route: "GET /gitignore/templates/Swift"),
        .init(tool: "list_codes_of_conduct", arguments: [:], response: .fixture("code-of-conduct-simple-items"), route: "GET /codes_of_conduct"),
        .init(
            tool: "get_code_of_conduct", arguments: ["key": "contributor_covenant"], response: .fixture("code-of-conduct"),
            route: "GET /codes_of_conduct/contributor_covenant"),
        .init(tool: "get_github_meta", arguments: [:], response: .fixture("api-overview"), route: "GET /meta"),
        .init(tool: "list_api_versions", arguments: [:], response: .json(#"["2022-11-28"]"#), route: "GET /versions"),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tested = Set(Self.cases.map(\.tool))
        let tools = Set((GitTools.tools(for: .readWrite) + MetaTools.tools(for: .readWrite)).map(\.name))
        #expect(tools.subtracting(tested).isEmpty, "Untested: \(tools.subtracting(tested).sorted())")
    }

    @Test func wholeListsComeBackAsOnePage() async throws {
        let (text, isError) = try await callTool("list_gitignore_templates", on: MockTransport(.json(#"["C","Swift"]"#)))
        #expect(!isError)
        #expect(text == #"{"items":["C","Swift"]}"#)
    }

    @Test func blobsComeBackAsText() async throws {
        let (text, isError) = try await callTool("get_git_blob", Self.with(["sha": "abc"]), on: MockTransport(.fixture("blob")))
        #expect(!isError)
        #expect(text.contains(#""text":"Content of the blob""#))
    }

    @Test func treeEntriesNeedOneSource() async throws {
        let transport = MockTransport(.fixture("git-tree", status: 201))
        let (text, isError) = try await callTool(
            "create_git_tree", Self.with(["entries": [["path": "a.txt", "content": "a", "delete": true]]]), on: transport)
        #expect(isError)
        #expect(text == "Entry `a.txt` needs exactly one of `content`, `sha`, or `delete`.")
        #expect(transport.requests.isEmpty)
    }

    @Test func markdownNeedsBothOwnerAndRepo() async throws {
        let transport = MockTransport(Self.html)
        let (text, isError) = try await callTool("render_markdown", ["text": "Hi", "owner": "o"], on: transport)
        #expect(isError)
        #expect(text == "Pass both `owner` and `repo`, or neither.")
        let (html, _) = try await callTool("render_markdown", ["text": "Hi"], on: transport)
        #expect(html == "<p>Hi</p>")
    }

    @Test func readOnlyHidesWrites() {
        let toolbox = GitHubToolbox(client: makeClient(MockTransport(.noContent())), toolsets: [.git, .meta], access: .readOnly)
        let names = Set(toolbox.tools.map(\.name))
        #expect(names.isSuperset(of: ["get_git_tree", "list_git_refs", "render_markdown", "get_license"]))
        #expect(names.isDisjoint(with: ["create_git_tree", "create_git_commit", "update_git_ref", "delete_git_ref"]))
        #expect(GitHubToolset.named("git") == .git)
        #expect(GitHubToolset.named("meta") == .meta)
    }
}
