# Changelog

All notable changes to GHKit are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and GHKit uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Issues: list issues across repositories, in an organization, or in one repository; open, update, close,
  reopen, lock, and unlock them; manage assignees, conversation comments (including pinning), labels, and
  milestones. Issues are `GitHubIssue`, so they don't clash with Swift Testing's `Issue`.
- Issue details: issue events, sub-issues (add, remove, reorder, parent), blocking dependencies, related
  issues, custom field values, GitHub's suggestions, and artifacts. Organizations can manage issue types and
  custom issue fields, and new or updated issues can set field values.
- Pull requests: list, get (or fetch as a diff or patch), open (also from an issue), update, close, reopen,
  commits, files, and the pull requests that contain a commit. Merge directly or in the background
  (including through the merge queue), update the branch, request and re-request reviewers, create, submit,
  update, dismiss, and delete reviews, manage review comments and replies, and build pull request stacks.
- Issue timelines as `TimelineEvent`, with typed comments, commits, reviews, cross-references, and line comments.
- Reactions: list, add, and remove emoji reactions on issues, pull requests, issue comments, commit comments,
  review comments, and releases. Pick the target with `ReactionSubject`.
- Search: code, commits, issues and pull requests (including advanced and semantic search), labels,
  repositories, topics, and users. Results are `SearchResult` values that read like the matched item and add
  the score and optional text matches; `summary()` gives the total count.

## [0.1.1] - 2026-11-03

### Added

- Swift Package Index configuration so the index can build and host the DocC documentation.
- DocC documentation for `GHKit` and `GHKitUI`, with getting-started, authentication, pagination, error-handling,
  and sign-in articles, published to GitHub Pages by the new Docs workflow on every release.

### Fixed

- DocC builds emit extension block symbols on every Swift version, tolerate the Xcode 26 symbol graph failure
  on the test module, and no longer rely on diagnostic flags missing from Xcode 26.
- Renamed DocC topic headings that clashed with article names.

## [0.1.0] - 2026-11-03

### Added

- `GitHubClient`: a `Sendable` client with typed throws, lazy `AsyncSequence` pagination, rate-limit handling,
  retries, GitHub Enterprise support, and escape hatches for any REST endpoint or GraphQL query.
- Authentication: personal access tokens, OAuth device flow, OAuth web flow with PKCE, automatic refresh of
  expiring tokens, GitHub App JWTs, installation tokens, OAuth token management, and Keychain storage.
- Projects (v2) for organizations and users: projects, fields, items, drafts, and views over REST, plus
  create, update, close, delete, copy, templates, links, collaborators, status updates, and item
  archiving and ordering over GraphQL.
- `GHKitUI`: `GitHubSession`, `GitHubSignInView`, `DeviceCodeView`, and the `\.gitHubClient` environment value.
- TODO.md coverage tracker generated from GitHub's OpenAPI description.
- Users: profile updates, the user directory, hovercards, followers, blocks, emails, GPG keys, SSH keys,
  SSH signing keys, and social accounts. Check endpoints such as `isFollowing(_:)` return a `Bool`.
- Organizations: profiles and settings, members, memberships, public membership, outside collaborators,
  invitations, blocks, and app installations, plus the signed-in user's memberships and invitations.
- Organization administration: webhooks with delivery history and redelivery, fine-grained organization
  roles for teams and users, and approval and revocation of fine-grained personal access tokens.
- Organization settings: custom and external repository properties, immutable releases policy, and
  API insights (request totals, usage over time, and usage per route, subject, and actor).
- Teams: create, update, nest, and delete teams; manage members and their roles; and grant, check,
  and remove repository access.
- Repositories: create (for you or an organization), get, update settings (merge options, security
  features), delete, transfer, and list; plus topics, languages, tags, teams, contributors, activity,
  community profile, and hash algorithm. `Repository` is one model for every repository payload.
- Repository contents: read files and directories (decoded or raw), write and delete files, README,
  license, CODEOWNERS errors, source archives, forks, syncing a fork, and creating from a template.
- Repository access: collaborators and their permissions, repository invitations (sent and received),
  deploy keys, and autolink references.
- Branches: list, get, rename, and merge branches, find branches by head commit, and manage every branch
  protection rule (status checks, reviews, admin enforcement, signed commits, and who can push).
- Rulesets for organizations and repositories: create, update, delete, version history, rule insights
  (rule suites), and the rules that apply to a branch. Every rule type is a typed `RepositoryRule` case.
- Releases: list, get (by ID, tag, or latest), create, update, publish, delete, and generate release notes;
  plus release assets: list, get, download, upload, rename, and delete.
- `GitHubServer.uploadsURL` for upload endpoints, set for github.com, Enterprise Server, and ghe.com.
- Commits: list (by ref, path, author, and date), get as JSON, diff, patch, or SHA, and compare two refs;
  plus commit comments and commit statuses (list, combined status, and create).
- Deployments and deployment statuses, and environments with their wait timers, required reviewers,
  deployment branch and tag patterns, and app-based protection rules. The model is `DeploymentEnvironment`
  so it doesn't clash with SwiftUI's `Environment`.
- Repository webhooks: create, update (including adding or removing single events), delete, ping, test,
  and delivery history with redelivery. Webhook types shared with organizations now live in `Webhooks.swift`.
- GitHub Pages: sites (create, update, custom domains, delete), builds, workflow artifact deployments,
  and DNS health checks.
- Traffic (views, clones, popular content, referrers) and commit statistics (code frequency, commit activity,
  contributors, participation, punch card). Statistics return `nil` while GitHub is still computing them.
- Repository security settings: check and toggle Dependabot alerts, Dependabot security updates, private
  vulnerability reporting, and immutable releases. Plus a repository's custom property values and
  `repository_dispatch` events.

### Fixed

- Redirects to another host, such as asset downloads, no longer carry the `Authorization` header.

[Unreleased]: https://github.com/emmanuel-defreitas/GHKit/compare/0.1.1...next
[0.1.1]: https://github.com/emmanuel-defreitas/GHKit/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/emmanuel-defreitas/GHKit/releases/tag/0.1.0
