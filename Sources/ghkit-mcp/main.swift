// A stdio MCP server that offers GHKit's GitHub tools, for trying them from an MCP client.
//
//   GITHUB_TOKEN=github_pat_… swift run ghkit-mcp
//
// Environment:
//   GITHUB_TOKEN        Required. The token the tools act with.
//   GHKIT_MCP_TOOLSETS  Comma-separated toolset names, or `all`. Default: the default toolsets.
//   GHKIT_MCP_WRITE     Set to 1 to offer tools that change GitHub. Default: read-only.

#if os(macOS)
    import Foundation
    import GHKit
    import GHKitMCP
    import MCP

    let environment = ProcessInfo.processInfo.environment

    func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("ghkit-mcp: \(message)\n".utf8))
        exit(1)
    }

    guard let token = environment["GITHUB_TOKEN"], !token.isEmpty else {
        fail("set GITHUB_TOKEN to a GitHub token")
    }

    var toolsets = Set<GitHubToolset>.defaults
    if let names = environment["GHKIT_MCP_TOOLSETS"], !names.isEmpty {
        toolsets =
            names == "all"
            ? .all
            : Set(
                names.split(separator: ",").map { name in
                    let name = name.trimmingCharacters(in: .whitespaces)
                    guard let toolset = GitHubToolset.named(name) else { fail("unknown toolset '\(name)'") }
                    return toolset
                })
    }

    let toolbox = GitHubToolbox(
        client: GitHubClient(token: token),
        toolsets: toolsets,
        access: environment["GHKIT_MCP_WRITE"] == "1" ? .readWrite : .readOnly
    )
    let server = await toolbox.makeServer(name: "ghkit-mcp", version: GHKitVersion.current)
    try await server.start(transport: StdioTransport())
    await server.waitUntilCompleted()
#else
    print("ghkit-mcp runs on macOS only.")
#endif
