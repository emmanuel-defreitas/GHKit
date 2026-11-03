import Foundation
import MCP
import Testing

@testable import GHKit
@testable import GHKitMCP

@Suite("MCP raw requests")
struct RawRequestToolsTests {
    func call(
        _ transport: MockTransport,
        access: GitHubToolAccess = .readOnly,
        _ name: String,
        _ arguments: [String: MCP.Value]
    ) async throws -> (text: String, isError: Bool) {
        let toolbox = GitHubToolbox(client: makeClient(transport), toolsets: [.rawRequests], access: access)
        let result = try #require(await toolbox.call(CallTool.Parameters(name: name, arguments: arguments)))
        guard case .text(let text, _, _)? = result.content.first else { return ("", true) }
        return (text, result.isError ?? false)
    }

    // MARK: REST

    @Test func sendsGetRequestsWithQueries() async throws {
        let transport = MockTransport(.json(#"[{"name": "bug"}]"#))
        let (text, isError) = try await call(
            transport, "github_rest",
            ["path": "/repos/octocat/hello-world/issues", "query": ["state": "open", "per_page": 5, "labels": ["bug", "ui"]]])
        #expect(!isError)
        #expect(text == #"[{"name":"bug"}]"#)
        #expect(transport.requests.map(\.route) == ["GET /repos/octocat/hello-world/issues"])
        #expect(transport.requests[0].queryItems == ["state": "open", "per_page": "5", "labels": "bug,ui"])
    }

    @Test func readOnlyRefusesWrites() async throws {
        let transport = MockTransport(.noContent())
        let (text, isError) = try await call(transport, "github_rest", ["method": "DELETE", "path": "/repos/o/r"])
        #expect(isError)
        #expect(text.contains("read-only"))
        #expect(transport.requests.isEmpty)
    }

    @Test func readWriteSendsBodies() async throws {
        let transport = MockTransport(.json(#"{"id": 1}"#, status: 201))
        let (text, _) = try await call(
            transport, access: .readWrite, "github_rest",
            ["method": "post", "path": "/repos/o/r/labels", "body": ["name": "bug", "color": "f00"]])
        #expect(text == #"{"id":1}"#)
        #expect(transport.requests.map(\.route) == ["POST /repos/o/r/labels"])
        #expect(transport.requests[0].jsonBody == ["name": "bug", "color": "f00"])
    }

    @Test func reportsEmptyResponses() async throws {
        let (text, isError) = try await call(MockTransport(.noContent()), access: .readWrite, "github_rest", ["method": "PUT", "path": "/user/starred/o/r"])
        #expect(!isError)
        #expect(text == "GitHub answered HTTP 204 with no content.")
    }

    @Test(arguments: [
        "https://evil.example/user", "//evil.example/user", "user", "/repos/../user", "/repos/%2E%2E/user", "/user?per_page=1",
    ])
    func refusesPathsThatLeaveTheAPI(path: String) async throws {
        let transport = MockTransport(.json("{}"))
        let (_, isError) = try await call(transport, "github_rest", ["path": .string(path)])
        #expect(isError)
        #expect(transport.requests.isEmpty)
    }

    // MARK: GraphQL

    @Test func runsQueries() async throws {
        let transport = MockTransport(.json(#"{"data": {"viewer": {"login": "octocat"}}}"#))
        let (text, isError) = try await call(
            transport, "github_graphql", ["query": "query($n: Int!) { viewer { login } }", "variables": ["n": 1]])
        #expect(!isError)
        #expect(text == #"{"viewer":{"login":"octocat"}}"#)
        #expect(transport.requests[0].url?.absoluteString == "https://api.github.com/graphql")
        #expect(transport.requests[0].jsonBody?["variables"] == ["n": 1])
    }

    @Test func readOnlyRefusesMutations() async throws {
        let transport = MockTransport(.json("{}"))
        let (text, isError) = try await call(transport, "github_graphql", ["query": "mutation { addStar(input: {}) { clientMutationId } }"])
        #expect(isError)
        #expect(text.contains("read-only"))
        #expect(transport.requests.isEmpty)
    }

    @Test(arguments: [
        ("mutation { addStar }", true),
        ("  # comment\n subscription { x }", true),
        ("query A { a } mutation B { b }", true),
        ("fragment F on User { login } mutation { x }", true),
        ("{ viewer { login } }", false),
        ("query { repository(name: \"mutation\") { mutation: name } }", false),
        ("query($mutation: Int) @mutation { a }", false),
        ("# mutation\nquery { a }", false),
        ("query { a(text: \"\"\"\nmutation { x }\n\"\"\") }", false),
        ("query { a(text: \"say \\\" mutation\") }", false),
        ("# comment\r\nmutation { x }", true),
        ("# comment\rmutation { x }", true),
        ("query { a(t: \"\"\" \\\"\"\" \"\"\") } mutation { x }", true),
        ("query { a(t: \"\"\" \\\"\"\" mutation { x } \"\"\") }", false),
    ])
    func detectsMutations(document: String, isMutation: Bool) {
        #expect(GraphQLDocument.hasMutation(document) == isMutation)
    }
}
