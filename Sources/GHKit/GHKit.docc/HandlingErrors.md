# Handling errors

Catch the failures you care about by name, and let GHKit retry the rest.

## Overview

Every GHKit API throws ``GitHubError`` using typed throws, so `catch` clauses can match its cases directly:

```swift
do {
    let project = try await acme.project(99)
} catch .notFound {
    // Missing, or this token can't see it
} catch .rateLimited(let limit, let retryAfter, _, _) {
    // limit?.reset says when to try again
} catch .unauthorized {
    await session.signOut()
} catch {
    print(error.localizedDescription)
}
```

When GitHub returns an error body, ``GitHubError/apiError`` has its message and validation details,
and ``GitHubError/metadata`` has the response headers. Include
``ResponseMetadata/requestID`` when you report a problem to GitHub.

### Retries

The client retries secondary rate limits and transient server errors, waiting as GitHub asks.
Change this with ``GitHubConfiguration/retryPolicy``, or turn it off:

```swift
let github = GitHubClient(token: token, configuration: GitHubConfiguration(retryPolicy: .none))
```

### Rate limits

``GitHubClient/rateLimit()`` returns your current limits for each resource. Every response also
reports the limit it counted against in ``ResponseMetadata/rateLimit``. To watch them as they change,
pass an `onResponse` handler to ``GitHubConfiguration``.
