# Exposing GitHub to AI assistants

Serve GitHub tools from your app, choose which ones, and decide whether they may change anything.

## Overview

An MCP server offers tools that an AI assistant, such as Claude, can call. ``GitHubToolbox``
provides GitHub tools for one: it lists them for `tools/list` and runs them for `tools/call`.

### Add the product

Add `GHKitMCP` next to `GHKit`. It brings in the MCP Swift SDK. Apps that only use `GHKit` or
`GHKitUI` don't download it.

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "GHKit", package: "GHKit"),
    .product(name: "GHKitMCP", package: "GHKit"),
])
```

GHKit and the `MCP` module both have a type named `PKCE`. In a file that imports both, write
``/GHKit/PKCE`` as `GHKit.PKCE`.

### Start a server

``GitHubToolbox/makeServer(name:version:instructions:)`` returns an MCP server with the tools
registered. Start it with any transport from the SDK, such as `StdioTransport` for a command-line
tool that an MCP client launches.

```swift
let toolbox = GitHubToolbox(client: GitHubClient(token: token))
let server = await toolbox.makeServer(name: "MyApp", version: "1.0")
try await server.start(transport: StdioTransport())
await server.waitUntilCompleted()
```

### Choose the tools

Pass the ``GitHubToolset`` values your assistant needs. Fewer tools make it easier for a model to
pick the right one. `Set.defaults` covers the common cases and `Set.all` includes everything.
Leave out individual tools by name with `excluding`.

```swift
let toolbox = GitHubToolbox(
    client: github,
    toolsets: [.context, .rawRequests],
    excluding: ["github_graphql"]
)
```

The ``GitHubToolset/rawRequests`` toolset adds `github_rest` and `github_graphql`, which reach any
endpoint. They only send paths to your client's API server, never full URLs, so the token stays
with GitHub.

### Allow changes

By default the toolbox is ``GitHubToolAccess/readOnly``: tools that create, change, or delete aren't
listed, `github_rest` only sends `GET` requests, and `github_graphql` refuses mutations. Pass
``GitHubToolAccess/readWrite`` to offer the rest. Each tool's MCP annotations say whether it only
reads or may destroy data, so clients can ask the user before running it.

```swift
let toolbox = GitHubToolbox(client: github, access: .readWrite)
```

The client's token still limits what any tool can do. A fine-grained token scoped to a few
repositories is the safest choice.

### Follow the signed-in user

When users sign in and out, pass a closure instead of a client. The toolbox asks for a client on
each call, and calls made while it returns `nil` tell the assistant to ask the user to sign in.

```swift
let session = GitHubSession(clientID: "Iv1.abc")   // from GHKitUI
let toolbox = GitHubToolbox { await session.client }
```

### Serve your own tools too

An MCP server has one handler per method. To mix GitHub tools with yours, list both and let the
toolbox try each call first. ``GitHubToolbox/call(_:)`` returns `nil` for tools it doesn't own.

```swift
await server.withMethodHandler(ListTools.self) { _ in
    ListTools.Result(tools: myTools + toolbox.tools)
}
await server.withMethodHandler(CallTool.self) { parameters in
    if let result = await toolbox.call(parameters) { return result }
    return try await callMyTool(parameters)
}
```

### Read the results

Tools return compact JSON. List tools return one page, as `{"items": […], "nextCursor": "…"}`;
the assistant passes `nextCursor` back as `cursor` for the next page and sets the page size with
`perPage`. Results longer than ``GitHubToolbox/maxOutputCharacters`` are cut short with a note.
Errors, such as a missing argument or a `404` from GitHub, come back as a result with `isError` set
and a message the assistant can act on.

### Try it in an MCP client

The package includes `ghkit-mcp`, a stdio server for macOS. Run it under the
[MCP Inspector](https://github.com/modelcontextprotocol/inspector):

```sh
GITHUB_TOKEN=github_pat_… npx @modelcontextprotocol/inspector swift run ghkit-mcp
```

Set `GHKIT_MCP_TOOLSETS` to a comma-separated list of toolset names, or `all`, and
`GHKIT_MCP_WRITE=1` to offer tools that change GitHub. To use it from Claude Desktop, build it with
`swift build -c release` and add it to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "github": {
      "command": "/path/to/GHKit/.build/release/ghkit-mcp",
      "env": { "GITHUB_TOKEN": "github_pat_…" }
    }
  }
}
```
