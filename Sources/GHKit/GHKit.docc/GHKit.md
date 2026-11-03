# ``GHKit``

The GitHub REST and GraphQL APIs for Swift apps, with async/await and typed throws.

@Metadata {
    @PageImage(purpose: icon, source: "ghkit-logo", alt: "The GHKit logo")
    @PageColor(orange)
}

## Overview

GHKit wraps GitHub's REST and GraphQL APIs in value types you call with `async`/`await`.
Start with a ``GitHubClient``, then reach each part of GitHub through an API type such as
``ProjectsAPI`` or ``RepositoriesAPI``.

```swift
import GHKit

let github = GitHubClient(token: "github_pat_…")

for try await project in github.projects(.organization("acme")).list(matching: "is:open") {
    print(project.number, project.title)
}
```

- Every call is `async` and throws ``GitHubError``, so you can `catch .notFound` or `catch .rateLimited`.
- List endpoints return ``Paginated``, an `AsyncSequence` that loads pages as you iterate.
- Personal tokens, OAuth device and web flows, and GitHub App credentials all plug into the same client.
  Expiring tokens refresh on their own.
- Secondary rate limits and transient server errors are retried, and a `401` triggers one credential refresh.
- Endpoints GHKit doesn't wrap yet are one ``GitHubRequest`` or GraphQL query away,
  with the same authentication, retries, and errors.

GHKit has no UI. For an observable sign-in session and ready-made SwiftUI views, add the GHKitUI library too.

## Topics

### Essentials

- <doc:GettingStarted>
- ``GitHubClient``
- ``GitHubConfiguration``
- ``GitHubServer``

### Signing in

- <doc:Authentication>
- ``Authenticator``
- ``TokenAuthenticator``
- ``AnonymousAuthenticator``
- ``BasicAuthenticator``
- ``AuthenticationStatus``

### OAuth

- ``DeviceFlow``
- ``DeviceAuthorization``
- ``OAuthWebFlow``
- ``AuthorizationRequest``
- ``PKCE``
- ``OAuthAuthenticator``
- ``OAuthCredential``
- ``OAuthScope``
- ``OAuthError``

### GitHub Apps

- ``GitHubAppCredentials``
- ``RSAPrivateKey``
- ``GitHubAppAuthenticator``
- ``InstallationAuthenticator``
- ``InstallationToken``
- ``InstallationTokenOptions``

### Credential storage

- ``CredentialStore``
- ``KeychainCredentialStore``
- ``KeychainError``
- ``InMemoryCredentialStore``

### GitHub APIs

- ``ProjectsAPI``
- ``ProjectOwner``
- ``RepositoriesAPI``
- ``RulesetsAPI``
- ``RulesetOwner``
- ``UsersAPI``
- ``OrganizationsAPI``
- ``TeamsAPI``
- ``AppsAPI``
- ``OAuthApplicationAPI``

### Paging through lists

- <doc:Pagination>
- ``Paginated``
- ``Page``
- ``PageCursor``
- ``LinkHeader``

### Errors and rate limits

- <doc:HandlingErrors>
- ``GitHubError``
- ``APIErrorResponse``
- ``GraphQLError``
- ``RetryPolicy``
- ``RateLimit``
- ``RateLimitOverview``
- ``ResponseMetadata``

### Custom requests

- <doc:CallingAnyEndpoint>
- ``GitHubRequest``
- ``GitHubResponse``
- ``HTTPMethod``
- ``RequestBody``
- ``NoVariables``

### Networking

- ``HTTPTransport``
- ``URLSessionTransport``

### Values

- ``JSONValue``
- ``CalendarDate``
- ``RichText``
- ``OpenEnum``
- ``GitHubJSON``
