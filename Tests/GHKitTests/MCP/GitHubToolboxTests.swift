import Foundation
import MCP
import Testing

@testable import GHKit
@testable import GHKitMCP

@Suite("MCP toolbox")
struct GitHubToolboxTests {
    let decoder = GitHubJSON.decoder()

    func toolbox(
        _ transport: MockTransport,
        toolsets: Set<GitHubToolset> = .all,
        access: GitHubToolAccess = .readOnly,
        excluding: Set<String> = [],
        maxOutputCharacters: Int = 100_000
    ) -> GitHubToolbox {
        GitHubToolbox(
            client: makeClient(transport), toolsets: toolsets, access: access, excluding: excluding,
            maxOutputCharacters: maxOutputCharacters)
    }

    func call(_ toolbox: GitHubToolbox, _ name: String, _ arguments: [String: MCP.Value] = [:]) async throws -> (text: String, isError: Bool) {
        let result = try #require(await toolbox.call(CallTool.Parameters(name: name, arguments: arguments)))
        guard case .text(let text, _, _)? = result.content.first else {
            Issue.record("Expected text content")
            return ("", true)
        }
        return (text, result.isError ?? false)
    }

    // MARK: Listing

    @Test func readOnlyListsOnlyReadTools() throws {
        let tools = toolbox(MockTransport(.noContent())).tools
        #expect(Set(tools.map(\.name)).isSuperset(of: ["get_me", "get_rate_limit", "github_rest", "github_graphql"]))
        #expect(tools.allSatisfy { $0.annotations.readOnlyHint == true && $0.annotations.destructiveHint == nil })
        let rest = try #require(tools.first { $0.name == "github_rest" })
        #expect(rest.inputSchema.objectValue?["properties"]?.objectValue?["method"]?.objectValue?["enum"] == ["GET"])
    }

    @Test func readWriteMarksRawRequestsDestructive() throws {
        let tools = toolbox(MockTransport(.noContent()), access: .readWrite).tools
        let rest = try #require(tools.first { $0.name == "github_rest" })
        #expect(rest.annotations.readOnlyHint == false)
        #expect(rest.annotations.destructiveHint == true)
        #expect(rest.inputSchema.objectValue?["properties"]?.objectValue?["method"]?.objectValue?["enum"]?.arrayValue?.count == 5)
    }

    @Test func filtersByToolsetAndName() {
        let transport = MockTransport(.noContent())
        #expect(toolbox(transport, toolsets: [.context]).tools.map(\.name) == ["get_me", "get_rate_limit"])
        #expect(Set(toolbox(transport, toolsets: .defaults).tools.map(\.name)).isSuperset(of: ["get_me", "get_repository"]))
        #expect(toolbox(transport, toolsets: [.rawRequests], excluding: ["github_graphql"]).tools.map(\.name) == ["github_rest"])
        #expect(GitHubToolset.named("raw_requests") == .rawRequests)
        #expect(GitHubToolset.named("nope") == nil)
    }

    @Test(arguments: [GitHubToolAccess.readOnly, .readWrite])
    func toolDefinitionsAreWellFormed(access: GitHubToolAccess) throws {
        let tools = GitHubToolset.everyToolset.flatMap { $0.makeTools(access) }
        #expect(Set(tools.map(\.name)).count == tools.count, "Tool names must be unique")
        for tool in tools {
            #expect(tool.name.allSatisfy { $0.isLowercase || $0 == "_" }, "\(tool.name) should be snake_case")
            #expect(!tool.description.isEmpty)
            let schema = try #require(tool.schema.objectValue)
            #expect(schema["type"] == "object")
            let properties = try #require(schema["properties"]?.objectValue, "\(tool.name) needs properties")
            for required in schema["required"]?.arrayValue ?? [] {
                #expect(properties[required.stringValue ?? ""] != nil, "\(tool.name) requires an unknown \(required)")
            }
            for (name, property) in properties {
                #expect(property.objectValue?["description"]?.stringValue?.isEmpty == false, "\(tool.name).\(name) needs a description")
            }
        }
    }

    // MARK: Calling

    @Test func getsTheSignedInUser() async throws {
        let transport = MockTransport(.fixture("private-user"))
        let (text, isError) = try await call(toolbox(transport), "get_me")
        #expect(!isError)
        #expect(transport.requests.map(\.route) == ["GET /user"])
        let user = try decoder.decode(User.self, from: Data(text.utf8))
        #expect(user.login == "octocat")
    }

    @Test func getsRateLimits() async throws {
        let transport = MockTransport(.fixture("rate-limit-overview"))
        let (text, _) = try await call(toolbox(transport), "get_rate_limit")
        #expect(transport.requests.map(\.route) == ["GET /rate_limit"])
        let expected = try decoder.decode(RateLimitOverview.self, from: loadFixture("rate-limit-overview"))
        #expect(try decoder.decode(RateLimitOverview.self, from: Data(text.utf8)) == expected)
    }

    @Test func ignoresToolsItDoesNotOwn() async {
        let toolbox = toolbox(MockTransport(.noContent()), toolsets: [.context])
        #expect(await toolbox.call(CallTool.Parameters(name: "github_rest")) == nil)
        #expect(await toolbox.call(CallTool.Parameters(name: "create_widget")) == nil)
    }

    @Test func reportsWhenSignedOut() async throws {
        let transport = MockTransport(.noContent())
        let toolbox = GitHubToolbox { nil }
        let (text, isError) = try await call(toolbox, "get_me")
        #expect(isError)
        #expect(text.contains("Not signed in"))
        #expect(transport.requests.isEmpty)
    }

    @Test func reportsGitHubErrors() async throws {
        let transport = MockTransport(.json(#"{"message": "Not Found"}"#, status: 404))
        let (text, isError) = try await call(toolbox(transport), "get_me")
        #expect(isError)
        #expect(text.hasPrefix("GitHub returned HTTP 404: Not Found"))
    }

    @Test func truncatesLongResults() async throws {
        let transport = MockTransport(.fixture("private-user"))
        let (text, isError) = try await call(toolbox(transport, maxOutputCharacters: 20), "get_me")
        #expect(!isError)
        #expect(text.hasPrefix(#"{"avatar_url":"https"#))
        #expect(text.contains("[Truncated: showing 20 of"))
    }

    @Test func registersOnAServer() async throws {
        let server = await toolbox(MockTransport(.fixture("private-user")), toolsets: [.context]).makeServer(name: "Test", version: "1")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: serverTransport)
        let client = MCP.Client(name: "TestClient", version: "1")
        _ = try await client.connect(transport: clientTransport)

        let (tools, _) = try await client.listTools()
        #expect(tools.map(\.name) == ["get_me", "get_rate_limit"])
        let result = try await client.callTool(name: "get_me")
        #expect(result.isError == false)
        await #expect(throws: MCPError.self) { try await client.callTool(name: "nope") }

        await client.disconnect()
        await server.stop()
    }

    // MARK: Arguments

    @Test func coercesArguments() throws {
        let arguments = ToolArguments(["n": "5", "d": 7.0, "flag": "true", "list": "bug", "none": nil, "empty": ""])
        #expect(try arguments.int("n") == 5)
        #expect(try arguments.int("d") == 7)
        #expect(try arguments.bool("flag", default: false))
        #expect(try arguments.strings("list") == ["bug"])
        #expect(try arguments.optionalString("none") == nil)
        #expect(try arguments.optionalString("empty") == nil)
        #expect(throws: ToolFailure.self) { try arguments.string("missing") }
        #expect(throws: ToolFailure.self) { try ToolArguments(["d": 7.5]).int("d") }
        #expect(try ToolArguments(["perPage": 500]).perPage == 100)
        #expect(try ToolArguments([:]).perPage == 30)
    }

    // MARK: Pages

    @Test func returnsOnePageWithACursor() async throws {
        let next = "https://api.github.com/repositories/1/labels?page=2"
        let transport = MockTransport(.json(#"[{"name": "bug"}]"#, headers: ["Link": "<\(next)>; rel=\"next\""]))
        let client = makeClient(transport)
        let list = client.paginate(GitHubRequest<[JSONValue]>(.get, "/repos/o/r/labels"))
        let context = GitHubTool.Context(client: client, access: .readOnly)

        let first = try await ToolOutput.page(list, ToolArguments([:]), context)
        #expect(first.text == #"{"items":[{"name":"bug"}],"nextCursor":"\#(next)"}"#)

        _ = try await ToolOutput.page(list, ToolArguments(["cursor": .string(next)]), context)
        #expect(transport.requests.last?.url?.absoluteString == next)
    }

    @Test(arguments: [
        "https://evil.example/repositories/1/labels?page=2",
        "http://api.github.com/repositories/1/labels?page=2",
        "https://api.github.com:8443/repositories/1/labels",
        "not a url",
    ])
    func refusesCursorsForOtherHosts(cursor: String) async throws {
        let transport = MockTransport(.json("[]"))
        let client = makeClient(transport)
        let list = client.paginate(GitHubRequest<[JSONValue]>(.get, "/repos/o/r/labels"))
        await #expect(throws: ToolFailure.self) {
            try await ToolOutput.page(list, ToolArguments(["cursor": .string(cursor)]), .init(client: client, access: .readOnly))
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func refusesCursorsOutsideTheEnterpriseAPIPath() throws {
        let server = GitHubServer(
            apiURL: URL(string: "https://ghe.example/api/v3")!, graphQLURL: URL(string: "https://ghe.example/api/graphql")!,
            webURL: URL(string: "https://ghe.example")!)
        let client = GitHubClient(token: "t", configuration: GitHubConfiguration(server: server), transport: MockTransport(.noContent()))
        #expect(try ToolArguments(["cursor": "https://ghe.example/api/v3/user/repos?page=2"]).cursor(for: client) != nil)
        #expect(throws: ToolFailure.self) { try ToolArguments(["cursor": "https://ghe.example/login?page=2"]).cursor(for: client) }
    }

    // MARK: Rate limit models

    @Test func rateLimitsRoundTrip() throws {
        let overview = try decoder.decode(RateLimitOverview.self, from: loadFixture("rate-limit-overview"))
        let again = try decoder.decode(RateLimitOverview.self, from: GitHubJSON.encoder().encode(overview))
        #expect(again == overview)
    }
}
