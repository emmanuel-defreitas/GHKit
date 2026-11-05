# Adding GitHub sign-in to a SwiftUI app

Show a sign-in screen, keep the user signed in across launches, and call GitHub from your views.

## Overview

Create one ``GitHubSession`` for your app. It needs the client ID of an OAuth app or GitHub App
with device flow turned on.

```swift
import SwiftUI
import GHKit
import GHKitUI

@main
struct MyApp: App {
    @State private var session = GitHubSession(clientID: "Iv1.abc123", domains: [.repositories, .projects], access: .write)

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isSignedIn {
                    ProjectsView()
                } else {
                    GitHubSignInView(session: session)
                }
            }
            .environment(session)
            .gitHubClient(session.client)
            .task { await session.restore() }
        }
    }
}
```

Passing `domains` asks for the scopes those parts of GitHub need. Pass `scopes:` instead to choose them yourself.

``GitHubSession/restore()`` loads a saved token and checks it, so returning users skip the sign-in screen.
``GitHubSignInView`` runs device flow: it shows the code, and opens GitHub for the user to enter it.

### Call GitHub from a view

Read the signed-in client from the environment. It's `nil` while the user is signed out.

```swift
struct ProjectsView: View {
    @Environment(\.gitHubClient) private var github
    @State private var projects: [Project] = []

    var body: some View {
        List(projects) { Text($0.title) }
            .task {
                guard let github else { return }
                projects = (try? await github.projects(.organization("acme")).list().collect()) ?? []
            }
    }
}
```

### Build your own sign-in screen

Call ``GitHubSession/startDeviceFlowSignIn()`` and show ``DeviceCodeView`` while
``GitHubSession/state`` is `awaitingAuthorization`. To sign in another way, pass a token to
``GitHubSession/signIn(token:)`` or a credential to ``GitHubSession/signIn(credential:)``.
``GitHubSession/signOut()`` forgets the token on this device.
