# Changelog

All notable changes to GHKit are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and GHKit uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/emmanuel-defreitas/GHKit/commits/next
