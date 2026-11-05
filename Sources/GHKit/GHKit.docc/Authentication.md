# Authentication

Sign in with a personal token, OAuth, or a GitHub App.

## Overview

Every ``GitHubClient`` has an ``Authenticator`` that adds credentials to each request.
When GitHub replies `401`, the client asks the authenticator to refresh once and retries.

| Credential | Best for | GHKit type |
|---|---|---|
| Personal access token | Scripts and personal tools | ``GitHubClient/init(token:configuration:transport:)`` |
| OAuth device flow | **Native apps (recommended).** No secret, no redirect URL. | ``DeviceFlow`` |
| OAuth web flow with PKCE | Apps with a backend for the code exchange | ``OAuthWebFlow`` |
| GitHub App JWT | `/app` endpoints, on a server | ``GitHubAppAuthenticator`` |
| GitHub App installation | Acting as an installation, on a server | ``InstallationAuthenticator`` |

### Device flow

Turn on device flow in your OAuth app or GitHub App settings, then:

```swift
let flow = DeviceFlow(clientID: "Iv1.abc123", scopes: [.repo, .project])

let authorization = try await flow.start()
// Show authorization.userCode and open authorization.verificationURL

let credential = try await flow.waitForAuthorization(authorization)

let github = GitHubClient(authenticator: OAuthAuthenticator(
    credential: credential,
    refresh: .init(clientID: "Iv1.abc123"),
    store: KeychainCredentialStore(service: "com.example.app")
))
```

Polling follows GitHub's interval and `slow_down` replies. Cancel the task to stop waiting.

``OAuthAuthenticator`` refreshes the token when it expires, sharing one refresh between concurrent
requests, and saves each refreshed credential to its ``CredentialStore``. In a SwiftUI app, GHKitUI's `GitHubSession` does all of this for you.

### Web flow

```swift
let flow = OAuthWebFlow(clientID: "abc", clientSecret: nil, redirectURI: URL(string: "myapp://oauth")!)
let request = flow.makeAuthorizationRequest()        // random state + PKCE challenge
// Open request.url, then on callback:
let credential = try await flow.exchange(callbackURL: callbackURL, for: request)
```

> Important: GitHub still requires the client secret for the code exchange. Don't ship it in your app.
> Exchange the code on your server with ``OAuthWebFlow/exchange(code:codeVerifier:)``, or use device flow.

### GitHub App installation

On a server, act as one installation of your GitHub App:

```swift
let app = try GitHubAppCredentials(issuer: "Iv23li…", privateKeyPEM: pem)
let github = GitHubClient(authenticator: InstallationAuthenticator(app: app, installationID: 42))
```

Installation tokens are minted on first use, cached, and renewed before they expire.
Concurrent requests share one token fetch.

To call the `/app` endpoints themselves, sign with the app's JWT using ``GitHubAppAuthenticator``.

### Ask for the right access

Each domain, such as ``GitHubDomain/issues``, declares the scopes and fine-grained permissions its
endpoints need. Combine the domains your app uses into a ``GitHubAccess`` and ask for exactly that:

```swift
let access = [GitHubDomain.repositories, .issues].access(.write)

// Device flow and OAuth apps take scopes.
let flow = DeviceFlow(clientID: "Iv1.abc", scopes: access.scopeList)

// Links that open GitHub's token form, filled in for the person to review.
let fineGrained = access.fineGrainedTokenURL(name: "My App", owner: "acme")
let classic = access.classicTokenURL(description: "My App")
```

For a GitHub App, set the permissions in ``GitHubAccess/permissions`` on the app's settings page.

Classic and OAuth tokens list their scopes, so you can check one before using it.
``GitHubClient/missingScopes(for:_:owner:)`` returns what's missing, or `nil` for credentials that
don't list scopes, such as fine-grained tokens. Those fail at call time instead, and
``GitHubError/missingAccess`` says which permissions the call needed.

### Use more than one credential

One classic or OAuth token can carry the scopes for every part of GitHub, so most apps need only one.
You need several when a credential only reaches one account, as a fine-grained personal access token or a
GitHub App installation does, or when you keep a powerful token, such as an organization admin token, apart
from the everyday one.

A ``RoutedAuthenticator`` picks a credential for each request from its domain, such as
`.issues` or `.organizations`, and the account it acts on:

```swift
let github = GitHubClient(authenticator: .routed(
    default: .token(personalToken),
    domains: [.organizations: .token(orgAdminToken)],
    owners: ["acme": InstallationAuthenticator(app: app, installationID: 42)]
))

try await github.organizations.members(of: "github")   // orgAdminToken
try await github.issues.issue(1, in: "acme", "app")     // the acme installation
try await github.users.authenticated()                  // personalToken
```

Each domain module declares its domains as ``GitHubDomain`` values. The account comes from the path,
such as `acme` in `/repos/acme/app`, or from the owner you pass, as in `github.projects(.organization("acme"))`.
Later pages of a list keep the first page's account. To route on something else, implement
``Authenticator/authenticator(for:)`` and read the ``GitHubRequestContext``.

### Store credentials

``KeychainCredentialStore`` keeps a credential in the Keychain. ``InMemoryCredentialStore`` is useful
in tests and on platforms without the Keychain. Conform to ``CredentialStore`` to keep credentials elsewhere.
