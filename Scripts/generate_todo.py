#!/usr/bin/env python3
"""Regenerates TODO.md from GitHub's OpenAPI description.

Usage:
    curl -sSL -o /tmp/api.json \
      https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json
    python3 Scripts/generate_todo.py /tmp/api.json > TODO.md

To record progress, edit DONE and IN_PROGRESS below (keyed by operationId), then rerun.
"""

import json
import sys
from collections import defaultdict
from datetime import date

# operationId -> Swift API that covers it
DONE = {
    # Authentication: users and rate limit
    "users/get-authenticated": "`github.users.authenticated()`, `github.verifyAuthentication()`",
    "users/get-by-username": "`github.users.user(_:)`",
    "users/get-by-id": "`github.users.user(id:)`",
    "rate-limit/get": "`github.rateLimit()`",
    # Authentication: GitHub Apps
    "apps/get-authenticated": "`apps.authenticatedApp()`",
    "apps/get-by-slug": "`apps.app(slug:)`",
    "apps/list-installations": "`apps.installations()`",
    "apps/get-installation": "`apps.installation(id:)`",
    "apps/get-org-installation": "`apps.installation(organization:)`",
    "apps/get-user-installation": "`apps.installation(user:)`",
    "apps/get-repo-installation": "`apps.installation(owner:repository:)`",
    "apps/create-installation-access-token": "`apps.createInstallationAccessToken(installationID:options:)`, `InstallationAuthenticator`",
    "apps/revoke-installation-access-token": "`apps.revokeInstallationAccessToken()`",
    "apps/delete-installation": "`apps.deleteInstallation(id:)`",
    "apps/suspend-installation": "`apps.suspendInstallation(id:)`",
    "apps/unsuspend-installation": "`apps.unsuspendInstallation(id:)`",
    "apps/list-installations-for-authenticated-user": "`apps.installationsForAuthenticatedUser()`",
    # Authentication: OAuth app token management
    "apps/check-token": "`oauthApplication(clientID:clientSecret:).checkToken(_:)`",
    "apps/reset-token": "`oauthApplication(…).resetToken(_:)`",
    "apps/delete-token": "`oauthApplication(…).deleteToken(_:)`",
    "apps/delete-authorization": "`oauthApplication(…).deleteGrant(_:)`",
    # Projects
    "projects/list-for-org": "`projects(.organization(_)).list(matching:perPage:)`",
    "projects/list-for-user": "`projects(.user(_)).list(matching:perPage:)`",
    "projects/get-for-org": "`projects(.organization(_)).project(_:)`",
    "projects/get-for-user": "`projects(.user(_)).project(_:)`",
    "projects/list-fields-for-org": "`fields(of:)`, `field(named:of:)`",
    "projects/list-fields-for-user": "`fields(of:)`, `field(named:of:)`",
    "projects/get-field-for-org": "`field(_:of:)`",
    "projects/get-field-for-user": "`field(_:of:)`",
    "projects/add-field-for-org": "`addField(_:to:)`",
    "projects/add-field-for-user": "`addField(_:to:)`",
    "projects/list-items-for-org": "`items(of:matching:fields:perPage:)`",
    "projects/list-items-for-user": "`items(of:matching:fields:perPage:)`",
    "projects/get-org-item": "`item(_:of:fields:)`",
    "projects/get-user-item": "`item(_:of:fields:)`",
    "projects/add-item-for-org": "`addItem(_:to:)`",
    "projects/add-item-for-user": "`addItem(_:to:)`",
    "projects/update-item-for-org": "`updateItem(_:in:_:)`",
    "projects/update-item-for-user": "`updateItem(_:in:_:)`",
    "projects/delete-item-for-org": "`deleteItem(_:from:)`",
    "projects/delete-item-for-user": "`deleteItem(_:from:)`",
    "projects/create-draft-item-for-org": "`addDraftIssue(title:body:to:)`",
    "projects/create-draft-item-for-authenticated-user": "`addDraftIssue(title:body:to:)`",
    "projects/create-view-for-org": "`createView(_:in:)`",
    "projects/create-view-for-user": "`createView(_:in:)`",
    "projects/list-view-items-for-org": "`items(inView:of:fields:perPage:)`",
    "projects/list-view-items-for-user": "`items(inView:of:fields:perPage:)`",
}

# operationId -> note
IN_PROGRESS: dict[str, str] = {}

MILESTONES = [
    ("M1", "Authentication & Projects", "✅ Done"),
    ("M2", "Core resources: users, organizations, teams, repositories", "⬜ Next"),
    ("M3", "Collaboration: issues, pull requests, search, activity", "⬜ Planned"),
    ("M4", "Automation: Actions, checks, packages, app webhooks", "⬜ Planned"),
    ("M5", "Security: code scanning, secret scanning, Dependabot", "⬜ Planned"),
    ("M6", "Platform & admin: Copilot, Codespaces, billing, migrations", "⬜ Planned"),
]

CATEGORY_MILESTONE = {
    "projects": "M1", "rate-limit": "M1",
    "users": "M2", "orgs": "M2", "teams": "M2", "repos": "M2", "git": "M2", "meta": "M2",
    "emojis": "M2", "licenses": "M2", "gitignore": "M2", "codes-of-conduct": "M2", "markdown": "M2",
    "issues": "M3", "pulls": "M3", "reactions": "M3", "search": "M3", "activity": "M3", "gists": "M3",
    "actions": "M4", "checks": "M4", "packages": "M4", "apps": "M4", "oidc": "M4",
    "hosted-compute": "M4", "private-registries": "M4", "agent-tasks": "M4", "agent-automations": "M4",
    "agent-merge": "M4", "agents": "M4",
    "code-scanning": "M5", "secret-scanning": "M5", "dependabot": "M5", "dependency-graph": "M5",
    "security-advisories": "M5", "code-security": "M5", "code-quality": "M5", "credentials": "M5",
    "campaigns": "M5",
}

METHODS = ("get", "post", "put", "patch", "delete")


def main(spec_path: str) -> None:
    with open(spec_path) as f:
        spec = json.load(f)

    by_category: dict[str, list[dict]] = defaultdict(list)
    for path, item in spec["paths"].items():
        for method in METHODS:
            op = item.get(method)
            if not op:
                continue
            category = (op.get("tags") or ["other"])[0]
            by_category[category].append({
                "method": method.upper(),
                "path": path,
                "id": op["operationId"],
                "summary": op.get("summary", "").strip(),
                "deprecated": op.get("deprecated", False),
            })

    total = sum(len(v) for v in by_category.values())
    done = sum(1 for v in by_category.values() for e in v if e["id"] in DONE)
    out = []
    w = out.append

    w("# GHKit API coverage\n")
    w(f"Tracks every GitHub REST endpoint, plus the GraphQL-only features GHKit wraps. "
      f"Generated from GitHub's [OpenAPI description](https://github.com/github/rest-api-description) "
      f"(version {spec['info']['version']}) on {date.today().isoformat()} by `Scripts/generate_todo.py`.\n")
    w("**Legend:** ✅ done · 🚧 in progress · ⬜ to do · ~~struck~~ deprecated by GitHub\n")
    w(f"**REST progress:** {done} of {total} endpoints ({done * 100 // total}%)\n")

    w("## Milestones\n")
    w("| Milestone | Scope | Status |")
    w("|---|---|---|")
    for key, name, status in MILESTONES:
        w(f"| {key} | {name} | {status} |")
    w("")

    w(MILESTONE_ONE_DETAILS)

    w("## Categories\n")
    w("| Category | Milestone | Done | Total | Status |")
    w("|---|---|---:|---:|---|")
    for category in sorted(by_category, key=lambda c: (CATEGORY_MILESTONE.get(c, "M6"), c)):
        endpoints = by_category[category]
        n_done = sum(1 for e in endpoints if e["id"] in DONE)
        n_prog = sum(1 for e in endpoints if e["id"] in IN_PROGRESS)
        status = "✅" if n_done == len(endpoints) else ("🚧" if n_done or n_prog else "⬜")
        milestone = CATEGORY_MILESTONE.get(category, "M6")
        if category == "apps":
            milestone = "M1 (auth) · M4 (rest)"
        w(f"| [{category}](#{category}) | {milestone} | {n_done} | {len(endpoints)} | {status} |")
    w("")

    w(GRAPHQL_SECTION)
    w(OAUTH_SECTION)
    w(LIBRARY_SECTION)

    w("## REST endpoints\n")
    for category in sorted(by_category, key=lambda c: (CATEGORY_MILESTONE.get(c, "M6"), c)):
        endpoints = sorted(by_category[category], key=lambda e: (e["path"], METHODS.index(e["method"].lower())))
        n_done = sum(1 for e in endpoints if e["id"] in DONE)
        w(f"### {category}\n")
        w(f"{n_done}/{len(endpoints)} done · milestone {CATEGORY_MILESTONE.get(category, 'M6')}\n")
        for e in endpoints:
            line = f"`{e['method']} {e['path']}` — {e['summary']}"
            if e["deprecated"]:
                line = f"~~{line}~~"
            if e["id"] in DONE:
                w(f"- [x] ✅ {line} → {DONE[e['id']]}")
            elif e["id"] in IN_PROGRESS:
                w(f"- [ ] 🚧 {line} ({IN_PROGRESS[e['id']]})")
            else:
                w(f"- [ ] {line}")
        w("")

    sys.stdout.write("\n".join(out))


MILESTONE_ONE_DETAILS = """### Milestone 1: Authentication & Projects ✅

**Authentication**
- [x] Personal access tokens, fine-grained and classic (`TokenAuthenticator`, `GitHubClient(token:)`)
- [x] OAuth device flow, with interval and `slow_down` handling (`DeviceFlow`)
- [x] OAuth web flow with PKCE and state checking (`OAuthWebFlow`), plus `ASWebAuthenticationSession` support in GHKitUI
- [x] Expiring user tokens, refreshed automatically with one shared refresh (`OAuthAuthenticator`)
- [x] GitHub App JWTs, RS256 signed with PKCS#1 or PKCS#8 keys (`GitHubAppAuthenticator`)
- [x] Installation tokens, minted and cached (`InstallationAuthenticator`)
- [x] OAuth app token check, reset, revoke, and grant deletion (`OAuthApplicationAPI`, Basic auth)
- [x] Credential storage in the Keychain or in memory (`KeychainCredentialStore`, `InMemoryCredentialStore`)
- [x] Token scope and expiry reporting (`verifyAuthentication()`)
- [x] SwiftUI: `GitHubSession` (`@Observable`), `GitHubSignInView`, `DeviceCodeView`, `\\.gitHubClient` environment value
- [ ] Scoped user tokens for GitHub Apps (`POST /applications/{client_id}/token/scoped`), moved to M4

**Projects (v2), for organizations and users**
- [x] List, get, filter projects
- [x] Fields: list, get, find by name, add (text, number, date, single select, iteration, issue field)
- [x] Items: list (with filters and field values), get, add issue or PR (by ID or by repo and number), add draft, update field values, delete
- [x] Views: create; list items in a view
- [x] GraphQL-backed: create, update, close, reopen, delete, copy, template on and off
- [x] GraphQL-backed: link to and unlink from repositories and teams; collaborators
- [x] GraphQL-backed: status updates (list, create, update, delete)
- [x] GraphQL-backed: archive, unarchive, reorder items; convert draft to issue; edit drafts
- [x] GraphQL-backed: rename fields, replace options or iterations, delete fields
- [ ] Project workflows (GraphQL `deleteProjectV2Workflow`, read-only workflow queries)
- [ ] View updates and deletion (not in the REST or GraphQL APIs yet)

Classic Projects (v1) aren't covered: GitHub removed them from the REST API.
"""

GRAPHQL_SECTION = """## GraphQL-only features

GitHub offers these only through GraphQL. GHKit wraps them behind the same `ProjectsAPI` methods.

| Mutation | Status | Swift API |
|---|---|---|
| `createProjectV2` | ✅ | `create(title:repositoryNodeID:teamNodeID:)` |
| `updateProjectV2` | ✅ | `update(_:title:shortDescription:readme:isPublic:)`, `close(_:)`, `reopen(_:)` |
| `deleteProjectV2` | ✅ | `delete(_:)` |
| `copyProjectV2` | ✅ | `copy(_:title:to:includeDraftIssues:)` |
| `markProjectV2AsTemplate` / `unmarkProjectV2AsTemplate` | ✅ | `markAsTemplate(_:)`, `unmarkAsTemplate(_:)` |
| `linkProjectV2ToRepository` / `unlinkProjectV2FromRepository` | ✅ | `link(_:toRepository:)`, `unlink(_:fromRepository:)` |
| `linkProjectV2ToTeam` / `unlinkProjectV2FromTeam` | ✅ | `link(_:toTeam:)`, `unlink(_:fromTeam:)` |
| `updateProjectV2Collaborators` | ✅ | `updateCollaborators(of:_:)` |
| `createProjectV2StatusUpdate` / `update…` / `delete…` | ✅ | `createStatusUpdate(in:…)`, `updateStatusUpdate(_:…)`, `deleteStatusUpdate(_:)` |
| `ProjectV2.statusUpdates` (query) | ✅ | `statusUpdates(of:limit:)` |
| `archiveProjectV2Item` / `unarchiveProjectV2Item` | ✅ | `archive(_:in:)`, `unarchive(_:in:)` |
| `updateProjectV2ItemPosition` | ✅ | `move(_:after:in:)` |
| `convertProjectV2DraftIssueItemToIssue` | ✅ | `convertDraftToIssue(_:in:repositoryNodeID:)` |
| `updateProjectV2DraftIssue` | ✅ | `updateDraftIssue(_:title:body:assigneeNodeIDs:)` |
| `updateProjectV2Field` / `deleteProjectV2Field` | ✅ | `updateField(_:name:options:iterations:)`, `deleteField(_:)` |
| `deleteProjectV2Workflow` | ⬜ | |
| Any other query or mutation | ✅ | `github.graphQL(_:variables:as:)` |
"""

OAUTH_SECTION = """## OAuth endpoints (github.com, outside the REST API)

| Endpoint | Status | Swift API |
|---|---|---|
| `GET /login/oauth/authorize` | ✅ | `OAuthWebFlow.makeAuthorizationRequest(login:allowSignup:)` |
| `POST /login/oauth/access_token` (code) | ✅ | `OAuthWebFlow.exchange(callbackURL:for:)`, `exchange(code:codeVerifier:)` |
| `POST /login/oauth/access_token` (refresh) | ✅ | `OAuthAuthenticator.refresh()`, `OAuthWebFlow.refresh(_:)` |
| `POST /login/device/code` | ✅ | `DeviceFlow.start()` |
| `POST /login/oauth/access_token` (device) | ✅ | `DeviceFlow.waitForAuthorization(_:)` |
"""

LIBRARY_SECTION = """## Library features

- [x] `async`/`await` everywhere, with typed throws (`throws(GitHubError)`)
- [x] `Sendable` value-type client; decoding runs off the caller's actor (`@concurrent`)
- [x] Lazy `AsyncSequence` pagination following `Link` headers (page and cursor styles), plus manual `page(_:at:)`
- [x] Rate limit parsing; automatic retry for secondary limits and server errors (`RetryPolicy`)
- [x] One automatic credential refresh and retry after a `401`
- [x] GitHub Enterprise Server and GHE.com data residency (`GitHubServer`)
- [x] Escape hatches: `GitHubRequest` for any REST endpoint, `graphQL(_:variables:as:)` for any query
- [x] Response hook for logging and rate-limit UI (`GitHubConfiguration.onResponse`)
- [ ] Conditional requests with ETag caching (`304 Not Modified` is already surfaced as `.notModified`)
- [ ] Webhook signature verification and payload models
- [ ] Typed GraphQL schema coverage beyond Projects
- [ ] Linux support (needs a swift-crypto fallback for PKCE and JWT signing)
- [ ] DocC catalog and a sample SwiftUI app
"""

if __name__ == "__main__":
    main(sys.argv[1])
