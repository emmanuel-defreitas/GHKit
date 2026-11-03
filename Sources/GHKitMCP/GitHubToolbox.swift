import Foundation
import GHKit
import MCP

/// GitHub API tools for a Model Context Protocol server, backed by a ``/GHKit/GitHubClient``.
///
/// Give an AI assistant access to GitHub as the signed-in user. Tools are read-only unless you
/// pass ``GitHubToolAccess/readWrite``.
///
///     let toolbox = GitHubToolbox(client: github, toolsets: [.context, .repositories])
///     let server = await toolbox.makeServer(name: "MyApp", version: "1.0")
///     try await server.start(transport: StdioTransport())
///
/// To serve your own tools too, list ``tools`` alongside yours and try ``call(_:)`` first.
public struct GitHubToolbox: Sendable {
    /// Returns the client to call GitHub with, or `nil` when no one is signed in.
    public typealias ClientProvider = @Sendable () async -> GitHubClient?

    /// The toolsets whose tools are listed.
    public let toolsets: Set<GitHubToolset>
    /// Whether tools that change GitHub are listed.
    public let access: GitHubToolAccess
    /// Longer results are cut to this many characters so they fit in a model's context.
    public let maxOutputCharacters: Int

    private let client: ClientProvider
    private let enabled: [GitHubTool]
    private let byName: [String: GitHubTool]

    /// A toolbox that always uses `client`.
    /// - Parameters:
    ///   - client: Sends the requests. Its token decides what the assistant can see and do.
    ///   - toolsets: Which tools to offer. Defaults to `Set.defaults`.
    ///   - access: Whether tools that change GitHub are offered. Defaults to read-only.
    ///   - excluding: Names of tools to leave out, such as `github_rest`.
    ///   - maxOutputCharacters: The longest result to return. Longer ones are truncated.
    public init(
        client: GitHubClient,
        toolsets: Set<GitHubToolset> = .defaults,
        access: GitHubToolAccess = .readOnly,
        excluding: Set<String> = [],
        maxOutputCharacters: Int = 100_000
    ) {
        self.init(
            toolsets: toolsets, access: access, excluding: excluding, maxOutputCharacters: maxOutputCharacters,
            client: { client })
    }

    /// A toolbox that asks for a client on each call, for apps where the user signs in and out.
    ///
    ///     let toolbox = GitHubToolbox { await session.client }
    ///
    /// Calls made while `client` returns `nil` fail with a "not signed in" message.
    public init(
        toolsets: Set<GitHubToolset> = .defaults,
        access: GitHubToolAccess = .readOnly,
        excluding: Set<String> = [],
        maxOutputCharacters: Int = 100_000,
        client: @escaping ClientProvider
    ) {
        self.toolsets = toolsets
        self.access = access
        self.maxOutputCharacters = max(maxOutputCharacters, 1)
        self.client = client
        enabled = GitHubToolset.everyToolset
            .filter(toolsets.contains)
            .flatMap { $0.makeTools(access) }
            .filter { (access == .readWrite || $0.kind == .read) && !excluding.contains($0.name) }
        byName = Dictionary(enabled.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The tools to return from `tools/list`.
    public var tools: [Tool] { enabled.map(\.definition) }

    /// Runs a `tools/call` request, or returns `nil` if the tool isn't one of this toolbox's.
    ///
    /// Problems the model can act on, such as a missing argument or a GitHub error, come back
    /// as a result with `isError` set, not as a thrown error.
    public func call(_ parameters: CallTool.Parameters) async -> CallTool.Result? {
        guard let tool = byName[parameters.name] else { return nil }
        guard let client = await client() else {
            return failure("Not signed in to GitHub. Ask the user to sign in, then try again.")
        }
        do {
            let output = try await tool.run(ToolArguments(parameters.arguments), .init(client: client, access: access))
            return CallTool.Result(content: [.text(text: output.truncated(to: maxOutputCharacters), annotations: nil, _meta: nil)], isError: false)
        } catch let error as GitHubError {
            return failure(Self.describe(error))
        } catch let error as ToolFailure {
            return failure(error.description)
        } catch {
            return failure("The tool failed: \(error)")
        }
    }

    /// Handles `tools/list` and `tools/call` on `server`, replacing any handlers it had for them.
    public func register(on server: Server) async {
        let tools = self.tools
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: tools) }
        await server.withMethodHandler(CallTool.self) { [self] parameters in
            guard let result = await call(parameters) else {
                throw MCPError.invalidParams("Unknown tool: \(parameters.name)")
            }
            return result
        }
    }

    /// A server that offers this toolbox's tools. Start it with a transport, such as `StdioTransport`.
    /// - Parameters:
    ///   - name: Your app's name, shown to MCP clients.
    ///   - version: Your app's version.
    ///   - instructions: Guidance for the assistant on how to use your server.
    public func makeServer(name: String, version: String, instructions: String? = nil) async -> Server {
        let server = Server(
            name: name,
            version: version,
            instructions: instructions,
            capabilities: Server.Capabilities(tools: .init(listChanged: false))
        )
        await register(on: server)
        return server
    }

    private func failure(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }

    /// A message the model can act on, with the HTTP status when there is one.
    static func describe(_ error: GitHubError) -> String {
        let message = error.localizedDescription
        let advice =
            switch error {
            case .unauthorized: " The token may have expired or been revoked."
            case .forbidden: " The token may lack the scope or permission this needs."
            case .notFound: " Check the names and numbers. Private resources also answer 404 without access."
            case .rateLimited: " Wait for the rate limit to reset before retrying."
            default: ""
            }
        guard let status = error.statusCode else { return message + advice }
        return "GitHub returned HTTP \(status): \(message)\(advice)"
    }
}
