# Contributing to GHKit

Thanks for helping! GHKit grows one GitHub API category at a time, and [TODO.md](TODO.md) shows what's next.

## Getting started

You need Swift 6.2+ (Xcode 26 or later).

```sh
git clone https://github.com/emmanuel-defreitas/GHKit.git
cd GHKit
swift build
swift test
```

Tests don't need network access or a GitHub token. They run against a mock transport.

## Picking something to work on

1. Open [TODO.md](TODO.md) and find an unchecked endpoint, ideally in the current milestone (M2 right now).
2. Open an issue saying what you'll take, so nobody duplicates the work.
3. Keep pull requests to one category or feature. Smaller is easier to review.

## Branches

| Branch | Role | Accepts PRs from |
|---|---|---|
| `dev` | Working branch; all feature work starts here | `feat/`, `fix/`, `doc/`, `ai/`, `core/` branches, and `next` (post-release sync) |
| `next` | Staging | `dev`, PRs titled `<type>(hotfix): …`, and `update(doc): …` PRs from the Update action |
| `main` | Production | `next` only |

All three branches are protected: they can't be deleted or force-pushed, changes go through pull requests, and CI (`Lint`, `Test (macOS)`, `Build (iOS)`) plus the `Branch policy` check must pass. Branch policy enforces the table above.

- Branch from `dev` and name the branch by type: `feat/projects-views`, `fix/pagination-cursor`, `doc/readme-auth`, `ai/…` for agent-written work, `core/…` for client internals.
- PR titles into `dev` must be [conventional](https://www.conventionalcommits.org): `feat(projects): add view updates`, `fix: retry on 502`, `feat!: rename ProjectOwner`. PRs into `dev` are squash-merged, so the title becomes the commit, and the release tooling reads it to pick the next version.
- When a PR merges into `dev`, its branch is deleted automatically.

### Stacked pull requests

Prefer a stack of small PRs over one large one. Each branch builds on the one before it:

```sh
git switch dev && git pull
git switch -c feat/issues-models            # PR 1: base dev
# …commit, push, open PR into dev
git switch -c feat/issues-api               # PR 2: base feat/issues-models
# …commit, push, open PR into feat/issues-models
```

Merge from the bottom up. When PR 1 merges, its branch is deleted and GitHub retargets PR 2 to `dev`. Because merges into `dev` are squashed, rebase the next branch onto `dev` before merging it:

```sh
git fetch origin
git rebase --onto origin/dev feat/issues-models feat/issues-api
git push --force-with-lease
```

## Releases

Releases are driven by GitHub Actions. Run them from the **Actions** tab.

1. **Stage:** open a PR from `dev` into `next` and merge it.
2. **Prepare:** works out the next version from what's on `next` but not on `main`, and opens a draft PR `next` → `main` titled `release: vX.Y.Z`. CI lints and tests it.
   - Breaking change (an API break found by `swift package diagnose-api-breaking-changes`, or a `!`/`BREAKING CHANGE` commit): major version (minor before 1.0).
   - Any `feat` commit: minor version.
   - Anything else: patch version.
3. **Promote:** marks the release PR ready and has Claude review it. If Claude finds problems, it opens a `fix(hotfix): …` PR into `next`; merge it and run Promote again. Otherwise the release PR is queued to merge when checks pass.
4. **Release** (runs on merge): tags the merge commit with the version (for example `0.2.0`), creates a GitHub release, and checks the Swift Package Index listing. SPI picks up new tags on its own.
   The **Docs** workflow also runs on the merge into `main` and publishes the DocC documentation to GitHub Pages.
5. **Update** (starts automatically): opens an `update(doc): …` PR into `next` that refreshes README.md, CHANGELOG.md, TODO.md, AGENTS.md, and CLAUDE.md, and bumps `GHKitVersion.current`. It merges when checks pass.
6. **Rebase** (runs when the update PR merges): opens a `next` → `dev` PR and merges it, so `dev` has the release docs and any hotfixes. `dev` can't be force-pushed, so this is a merge rather than a history rewrite.

For an urgent fix, branch from `next`, open a PR into `next` titled `fix(hotfix): …`, then run Prepare and Promote.

## Adding endpoints

Each part of GitHub is its own module in `Sources/GHKit<Domain>/`, such as `Sources/GHKitIssues/`.
Follow the pattern there (see `Sources/GHKitProjects/Projects/ProjectsAPI.swift`):

- **Module:** put the endpoint in the domain's module. Domain modules depend only on `GHKitCore`, never on each other.
  If two domains need the same model, it goes in `Sources/GHKitCore/Models/`. A core helper that domains call,
  like `escape(_:)`, is `package`, not `public`.
- **Namespace:** expose a value-type API from `GitHubClient`, for example `github.issues`.
- **Signatures:** `async throws(GitHubError)`. Return `Paginated<T>` for list endpoints.
- **Doc comments:** one line on what the method does, plus the HTTP method and path, for example ``/// `GET /repos/{owner}/{repo}/issues` ``.
- **Models:** go in the domain's `Models/` folder, or `Sources/GHKitCore/Models/` when shared. They're `Sendable`, `Hashable` and `Codable`, with explicit `CodingKeys` and Swift-style names (`nodeID`, `htmlURL`, `createdAt`).
- **Fields:** make a field optional unless GitHub's schema marks it required.
- **Enums GitHub may extend:** use `OpenEnum` structs, not Swift enums, so new values don't break decoding.
- **Path segments:** escape user-supplied values with `escape(_:)`.
- **GraphQL-only features:** wrap them in the same API type and return REST models where possible (see `ProjectsAPI+Management.swift`).

## Tests

Every endpoint needs a test that checks:

- the request: method, path, query, and JSON body
- the response decoding, using a fixture

Fixtures live in `Tests/GHKitTests/Fixtures/`. Take them from GitHub's OpenAPI examples so they match real payloads:

```sh
curl -sSL -o /tmp/api.json \
  https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json
jq '.components.examples["issue"].value' /tmp/api.json > Tests/GHKitTests/Fixtures/issue.json
```

Use Swift Testing (`@Test`, `#expect`), `MockTransport`, and `makeClient(_:)` from `GHKitTests.swift`.

## Documentation

The API reference is built with DocC from doc comments plus the catalogs in `Sources/GHKit/GHKit.docc` (it documents every domain module, since `GHKit` re-exports them) and
`Sources/GHKitUI/GHKitUI.docc`. Each catalog has a landing page that groups the main types into topics, and
articles for the main features.

```sh
Scripts/build_docs.sh                                        # builds .build/docs/site for GitHub Pages
DOCS_BASE_PATH= Scripts/build_docs.sh                        # builds it to serve from the root, then:
python3 -m http.server --directory .build/docs/site 8000     # open http://localhost:8000
```

The build fails on broken symbol links and other DocC warnings, except incomplete `- Parameters:` lists.
The **Docs** workflow runs the same script on every pull request and publishes to GitHub Pages from `main`.

- Link symbols with double backticks, for example ``` ``GitHubClient/paginate(_:)`` ```.
  From GHKitUI, link GHKit symbols with an absolute path: ``` ``/GHKit/OAuthWebFlow`` ```.
- When you add an important public type, list it under a topic in the module's landing page.
  Types you don't list are grouped by kind automatically.

## Updating TODO.md

After adding endpoints, add their `operationId`s to `DONE` in `Scripts/generate_todo.py` and regenerate:

```sh
python3 Scripts/generate_todo.py /tmp/api.json > TODO.md
```

Don't edit TODO.md by hand. The script overwrites it.

## Before opening a pull request

- [ ] `swift build` has no warnings
- [ ] `swift test` passes
- [ ] It builds for iOS: `xcodebuild -scheme GHKit-Package -destination "generic/platform=iOS" build`
- [ ] New public APIs have doc comments
- [ ] `Scripts/build_docs.sh` succeeds (no broken doc links)
- [ ] TODO.md is regenerated
- [ ] The README is updated if you added something users will reach for first

## Style

- Swift 6 strict concurrency; no `@unchecked Sendable` in library code.
- Prefer value types. Use actors only for shared mutable state, such as token caches.
- No third-party dependencies in `GHKit`.
- Write doc comments in plain language, and say what a thing does rather than how.

## Reporting bugs

Open an issue with the GHKit version, platform, a minimal code sample, and the `GitHubError` you got. If it's an API error, include `error.metadata?.requestID`, the `x-github-request-id` header, but never a token.

## License

By contributing, you agree your contributions are licensed under the [MIT License](LICENSE).
