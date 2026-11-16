# Getting started

Add GHKit to your project, make a client, and call your first endpoint.

## Overview

GHKit needs Swift 6.2 or later (Xcode 26), and runs on iOS 17, macOS 14, tvOS 17, watchOS 10, and visionOS 1.

### Add the package

In Xcode, choose **File → Add Package Dependencies…** and enter
`https://github.com/emmanuel-defreitas/GHKit.git`. Or add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/emmanuel-defreitas/GHKit.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "GHKit", package: "GHKit"),     // every domain; or pick some, such as "GHKitIssues"
        .product(name: "GHKitUI", package: "GHKit"),   // optional SwiftUI helpers
    ]),
]
```

| Product | What's in it |
|---|---|
| `GHKit` | Every domain module, in one import. No UI. |
| `GHKitCore` | ``GitHubClient``, authentication, pagination, GraphQL, custom requests, and shared models. |
| `GHKitUsers`, `GHKitRepositories`, `GHKitIssues`, `GHKitPullRequests`, `GHKitOrganizations`, `GHKitProjects`, `GHKitActivity`, `GHKitGists`, `GHKitSearch`, `GHKitApps`, `GHKitMeta` | One part of GitHub each. Importing one adds its API to the client, such as `github.issues`. |
| `GHKitUI` | An observable sign-in session, sign-in views, and the `\.gitHubClient` environment value. |

Each domain module brings `GHKitCore` with it. This reference documents every module under GHKit,
and each API type's page says which library it's in.

### Make a client

A ``GitHubClient`` holds your credentials and configuration. It's a value type, so you can pass it
around and share it between tasks.

```swift
import GHKit

let github = GitHubClient(token: "github_pat_…")

let status = try await github.verifyAuthentication()
print("Signed in as \(status.user.login) with scopes \(status.scopes ?? [])")

let limits = try await github.rateLimit()
print("\(limits.core?.remaining ?? 0) requests left this hour")
```

A personal access token suits scripts and personal tools. Apps should sign users in with OAuth instead;
see <doc:Authentication>.

### Call an API

Each part of GitHub has its own API type, reached from the client:

```swift
let me = try await github.users.authenticated()

let acme = github.projects(.organization("acme"))   // or .user("octocat")
let roadmap = try await acme.project(1)
```

| Client member | API |
|---|---|
| ``GitHubClient/projects(_:)`` | ``ProjectsAPI`` |
| ``GitHubClient/repositories`` | ``RepositoriesAPI`` |
| ``GitHubClient/rulesets(_:)`` | ``RulesetsAPI`` |
| ``GitHubClient/users`` | ``UsersAPI`` |
| ``GitHubClient/organizations`` | ``OrganizationsAPI`` |
| ``GitHubClient/teams`` | ``TeamsAPI`` |
| ``GitHubClient/apps`` | ``AppsAPI`` |

Each method's documentation names the REST endpoint or GraphQL feature it calls.

### Use GitHub Enterprise

Point the client at GitHub Enterprise Server or GHE.com with a ``GitHubConfiguration``:

```swift
let config = GitHubConfiguration(server: .enterpriseServer(URL(string: "https://github.example.com")!))
// or .enterpriseCloud(subdomain: "acme") for acme.ghe.com

let github = GitHubClient(token: token, configuration: config)
```

The configuration also sets the REST API version, the `User-Agent` header, and the ``RetryPolicy``.

### Swap the transport

``GitHubClient`` sends requests through an ``HTTPTransport``. The default, ``URLSessionTransport``,
uses `URLSession`. Provide your own to add logging or caching, or to stub responses in tests.
