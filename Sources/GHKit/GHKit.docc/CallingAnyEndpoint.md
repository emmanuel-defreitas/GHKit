# Calling any endpoint

Reach REST endpoints and GraphQL queries that GHKit doesn't wrap yet.

## Overview

GHKit's API types cover a growing share of GitHub's REST API. For everything else, describe the
request yourself and send it through the same client, with the same authentication, retries, and errors.

### REST

A ``GitHubRequest`` names the method, path, query, and body, and the type to decode:

```swift
struct Label: Decodable, Sendable { let name: String; let color: String }

let labels = try await github
    .paginate(GitHubRequest<[Label]>(.get, "/repos/acme/app/labels"))
    .collect()
```

Use ``GitHubClient/value(_:)`` for a single response, ``GitHubClient/send(_:)`` when you also need
the ``ResponseMetadata``, and ``GitHubClient/paginate(_:)`` for lists.

> Tip: Percent-encode any user-supplied path segment, such as a branch name that contains a `/`.

### GraphQL

Decode a query's `data` into your own type:

```swift
struct Viewer: Decodable, Sendable {
    struct User: Decodable, Sendable { let login: String }
    let viewer: User
}

let viewer = try await github.graphQL("query { viewer { login } }", as: Viewer.self)
```

Pass `variables` with any `Encodable` value. GraphQL errors arrive as ``GitHubError/graphQL(_:)``.
