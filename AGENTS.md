# AGENTS.md

Guidance for AI coding agents working on GHKit. Humans: see [CONTRIBUTING.md](CONTRIBUTING.md).

## What this is

GHKit is a Swift package wrapping the GitHub REST and GraphQL APIs for SwiftUI apps.
`GHKitCore` holds the client, auth, pagination, GraphQL, and shared models. Each part of GitHub is its own
library on top of it (`GHKitUsers`, `GHKitRepositories`, `GHKitIssues`, `GHKitPullRequests`, `GHKitOrganizations`,
`GHKitProjects`, `GHKitActivity`, `GHKitGists`, `GHKitSearch`, `GHKitApps`), and `GHKit` re-exports all of them.
`GHKitUI` adds a SwiftUI session and views, and `GHKitMCP` exposes the API to AI assistants as Model Context Protocol tools.
Coverage and the roadmap live in [TODO.md](TODO.md), which is generated; never edit it by hand.

## Commands

```sh
swift build                                                     # must be warning-free
swift test                                                      # Swift Testing, no network needed
swift format lint --strict --recursive Sources Tests Package.swift
swift format format --in-place --recursive Sources Tests Package.swift
xcodebuild -scheme GHKit-Package -destination "generic/platform=iOS" build -quiet
python3 Scripts/generate_todo.py /path/to/api.json > TODO.md    # after adding endpoints
Scripts/build_docs.sh                                           # DocC site in .build/docs/site; fails on broken doc links
```

## Layout

| Path | Contents |
|---|---|
| `Sources/GHKitCore/Client/` | `GitHubClient`, pagination (`Paginated`, `Page`), GraphQL |
| `Sources/GHKitCore/HTTP/` | Transport, configuration, `GitHubRequest`, `GitHubError`, response metadata |
| `Sources/GHKitCore/Auth/` | Authenticators, OAuth device and web flows, GitHub App JWT and installation tokens, credential stores |
| `Sources/GHKitCore/Models/` | Models more than one domain uses (`SimpleUser`, `Repository`, `GitHubIssue`, `Team`, `OpenEnum`, …) |
| `Sources/GHKitCore/Core/` | `JSONValue`, `CalendarDate`, `RichText`, JSON coders |
| `Sources/GHKit<Domain>/` | One domain each: its API types (`IssuesAPI`, `ReactionsAPI`, …), and its own models and inputs in `Models/` |
| `Sources/GHKit/` | The umbrella module (`@_exported` imports only) and the `GHKit.docc` catalog that documents every domain |
| `Sources/GHKitUI/` | `GitHubSession`, sign-in views, environment values (main-actor by default) |
| `Sources/GHKitMCP/` | `GitHubToolbox`, toolsets, and one `Tools/<Category>Tools.swift` per toolset |
| `Sources/ghkit-mcp/` | Stdio MCP server for trying the tools (`swift run ghkit-mcp`, macOS only) |
| `Sources/*/*.docc/` | DocC catalogs: landing pages (topic groups) and articles |
| `Tests/GHKitTests/` | Tests, `MockTransport`, fixtures from GitHub's OpenAPI examples |
| `Scripts/generate_todo.py` | Builds TODO.md from GitHub's OpenAPI description |
| `Scripts/build_docs.sh` | Builds the combined DocC site that the Docs workflow publishes to GitHub Pages |
| `.github/` | CI, docs, branch policy, and release workflows |

## Conventions

- Swift 6.2, strict concurrency, upcoming features on (`NonisolatedNonsendingByDefault`, `ExistentialAny`, …).
- Public async APIs use typed throws: `async throws(GitHubError)`. List endpoints return `Paginated<T>`.
- Models: `Sendable, Hashable, Codable`, explicit `CodingKeys`, Swift names (`nodeID`, `htmlURL`).
  Optional unless GitHub's schema marks the field required.
- Values GitHub may extend use `OpenEnum` structs, not Swift enums.
- Escape user-supplied path segments with `escape(_:)`.
- Each domain module declares its `GitHubDomain` values in `Domains.swift`, with the scopes and fine-grained
  permissions its read and write endpoints need (permission names from GitHub's `app-permissions` schema).
  API accessors pass the client through `scoped(to:)` so requests carry their domain.
- New endpoints go in their domain module. Domain modules depend only on `GHKitCore`, never on each other:
  a model two domains need moves to `Sources/GHKitCore/Models/`, and core helpers they call are `package`.
- GraphQL-only features are wrapped in the same API type and return REST models when possible.
- No third-party dependencies in `GHKit` or `GHKitUI`. `GHKitMCP` depends only on the official MCP Swift SDK.
  No `@unchecked Sendable` in library code.
- MCP tools: snake_case names, a `GitHubTool.Kind` that matches what they do, and list tools that return
  one page via `ToolOutput.page`. Write tools are hidden in read-only toolboxes, so mark them `.write` or `.destructive`.
- Doc comments: one plain sentence, then the HTTP method and path.
  Link symbols with double backticks; from GHKitUI, link GHKit symbols absolutely (``` ``/GHKit/OAuthWebFlow`` ```).
- New public types: add the important ones to a topic group in `GHKit.docc/GHKit.md` (it covers every domain module).
  Each `*API` type's doc comment ends with "Part of the `GHKit<Domain>` library."
- Every endpoint gets a test for the request (method, path, query, body) and for decoding a fixture.
  So does every MCP tool, in `Tests/GHKitTests/MCP/`.

## Branches and pull requests

| Branch | Role | Accepts PRs from |
|---|---|---|
| `dev` | Working branch | `feat/`, `fix/`, `doc/`, `ai/`, `core/` branches; `next` (sync) |
| `next` | Staging | `dev`; titles `<type>(hotfix): …`; titles `update(doc): …` |
| `main` | Production | `next` only |

- Branch from `dev`. Name AI-authored branches `ai/<topic>`.
- PR titles into `dev` must be conventional (`feat(projects): …`, `fix: …`, `feat!: …` for breaking).
  They become the squash commit and decide the next version.
- Prefer stacked PRs: one small concern per branch, each based on the previous branch.
- Never push to `dev`, `next`, or `main` directly, and never merge PRs yourself unless asked.

## Releases

`Prepare` → `Promote` → (merge) `Release` → `Update` → `Rebase`. See CONTRIBUTING.md for details.
Tags are plain semver (`0.2.0`). Before 1.0, breaking changes bump the minor version.
