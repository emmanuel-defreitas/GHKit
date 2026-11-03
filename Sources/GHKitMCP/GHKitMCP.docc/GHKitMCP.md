# ``GHKitMCP``

Let AI assistants use GitHub through your app, over the Model Context Protocol.

## Overview

GHKitMCP turns GHKit's API into MCP tools. A ``GitHubToolbox`` lists the tools and runs tool calls
with your app's ``/GHKit/GitHubClient``, so the assistant acts as the signed-in user, with the same
authentication, retries, and errors as the rest of your app.

```swift
import GHKit
import GHKitMCP
import MCP

let toolbox = GitHubToolbox(client: github, toolsets: [.context, .rawRequests])
let server = await toolbox.makeServer(name: "MyApp", version: "1.0")
try await server.start(transport: StdioTransport())
```

Tools are grouped into ``GitHubToolset`` values and only read from GitHub unless you pass
``GitHubToolAccess/readWrite``. The `MCP` module comes from the official
[MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk), which supplies the server and
its transports.

- <doc:ExposingGitHubToAssistants>

## Topics

### Essentials

- <doc:ExposingGitHubToAssistants>
- ``GitHubToolbox``

### Choosing tools

- ``GitHubToolset``
- ``GitHubToolAccess``
