# AGENTS.md

Guidance for AI coding agents working on GHKit. Humans: see [CONTRIBUTING.md](CONTRIBUTING.md).

## What this is

GHKit is a Swift package wrapping the GitHub REST and GraphQL APIs for SwiftUI apps.
Two products: `GHKit` (client, auth, models, APIs; no UI) and `GHKitUI` (SwiftUI session and views).
Coverage and the roadmap live in [TODO.md](TODO.md), which is generated; never edit it by hand.

## Commands

```sh
swift build                                                     # must be warning-free
swift test                                                      # Swift Testing, no network needed
swift format lint --strict --recursive Sources Tests Package.swift
swift format format --in-place --recursive Sources Tests Package.swift
xcodebuild -scheme GHKit-Package -destination "generic/platform=iOS" build -quiet
python3 Scripts/generate_todo.py /path/to/api.json > TODO.md    # after adding endpoints
```

## Layout

| Path | Contents |
|---|---|
| `Sources/GHKit/Client/` | `GitHubClient`, pagination (`Paginated`, `Page`), GraphQL |
| `Sources/GHKit/HTTP/` | Transport, configuration, `GitHubRequest`, `GitHubError`, response metadata |
| `Sources/GHKit/Auth/` | Authenticators, OAuth device and web flows, GitHub App JWT and installation tokens, credential stores |
| `Sources/GHKit/API/` | One API type per GitHub category (`ProjectsAPI`, `UsersAPI`, `OrganizationsAPI`, `TeamsAPI`, `RepositoriesAPI`, `AppsAPI`) |
| `Sources/GHKit/Models/` | Codable models and request inputs |
| `Sources/GHKit/Core/` | `JSONValue`, `CalendarDate`, `RichText`, JSON coders |
| `Sources/GHKitUI/` | `GitHubSession`, sign-in views, environment values (main-actor by default) |
| `Tests/GHKitTests/` | Tests, `MockTransport`, fixtures from GitHub's OpenAPI examples |
| `Scripts/generate_todo.py` | Builds TODO.md from GitHub's OpenAPI description |
| `.github/` | CI, branch policy, and release workflows |

## Conventions

- Swift 6.2, strict concurrency, upcoming features on (`NonisolatedNonsendingByDefault`, `ExistentialAny`, …).
- Public async APIs use typed throws: `async throws(GitHubError)`. List endpoints return `Paginated<T>`.
- Models: `Sendable, Hashable, Codable`, explicit `CodingKeys`, Swift names (`nodeID`, `htmlURL`).
  Optional unless GitHub's schema marks the field required.
- Values GitHub may extend use `OpenEnum` structs, not Swift enums.
- Escape user-supplied path segments with `escape(_:)`.
- GraphQL-only features are wrapped in the same API type and return REST models when possible.
- No third-party dependencies in `GHKit`. No `@unchecked Sendable` in library code.
- Doc comments: one plain sentence, then the HTTP method and path.
- Every endpoint gets a test for the request (method, path, query, body) and for decoding a fixture.

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
