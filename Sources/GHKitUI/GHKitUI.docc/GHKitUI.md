# ``GHKitUI``

Sign users in to GitHub from a SwiftUI app and share the client with your views.

## Overview

GHKitUI builds on GHKit. ``GitHubSession`` runs OAuth device flow, keeps the token in the Keychain,
restores it at launch, refreshes it when it expires, and publishes the latest rate limit.
``GitHubSignInView`` is a ready-made sign-in screen, and the `\.gitHubClient` environment value
hands the signed-in client to any view.

- <doc:AddingSignIn>

## Topics

### Essentials

- <doc:AddingSignIn>
- ``GitHubSession``

### Sign-in views

- ``GitHubSignInView``
- ``DeviceCodeView``

### Environment

- ``SwiftUICore/EnvironmentValues/gitHubClient``
- ``SwiftUICore/View/gitHubClient(_:)``

### Web flow

- ``GHKit/OAuthWebFlow/authenticate(using:callbackURLScheme:ephemeral:)``
