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

### Store credentials

``KeychainCredentialStore`` keeps a credential in the Keychain. ``InMemoryCredentialStore`` is useful
in tests and on platforms without the Keychain. Conform to ``CredentialStore`` to keep credentials elsewhere.
