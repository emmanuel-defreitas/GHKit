import Foundation
import GHKit
import Observation

/// Sign-in state for a SwiftUI app, backed by the Keychain.
///
///     @main struct MyApp: App {
///         @State private var session = GitHubSession(clientID: "Iv1.abc", scopes: [.repo, .project])
///         var body: some Scene {
///             WindowGroup {
///                 RootView()
///                     .environment(session)
///                     .gitHubClient(session.client)
///                     .task { await session.restore() }
///             }
///         }
///     }
///
/// The module uses main-actor isolation by default, so the session is safe to read from views.
@Observable
public final class GitHubSession {
    public enum State: Equatable {
        /// `restore()` hasn't finished yet.
        case restoring
        case signedOut
        /// Device flow is waiting for the user to enter the code.
        case awaitingAuthorization(DeviceAuthorization)
        case signedIn(User)
    }

    public private(set) var state: State = .restoring
    /// A client for the signed-in user, or `nil` when signed out.
    public private(set) var client: GitHubClient?
    /// The most recent rate limit GitHub reported.
    public private(set) var rateLimit: RateLimit?
    /// The last sign-in error, cleared when a new sign-in starts.
    public private(set) var lastError: GitHubError?
    /// Scopes GitHub reported for the current token.
    public private(set) var grantedScopes: [OAuthScope]?

    /// The OAuth app or GitHub App client ID used for device flow.
    public let clientID: String
    /// The scopes device flow asks for.
    public let scopes: [OAuthScope]
    /// The GitHub instance to sign in to.
    public let server: GitHubServer

    @ObservationIgnored private let store: any CredentialStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private var signInTask: Task<Void, Never>?

    /// Creates a signed-out session. Call ``restore()`` at launch to load a saved token.
    /// - Parameters:
    ///   - clientID: Your OAuth app or GitHub App client ID, with device flow enabled.
    ///   - scopes: OAuth app scopes. GitHub Apps ignore them.
    ///   - server: The GitHub instance to sign in to. Defaults to GitHub.com.
    ///   - store: Where the token is kept. Defaults to the Keychain.
    ///   - transport: Sends HTTP requests. Replace it to stub responses in tests.
    public init(
        clientID: String,
        scopes: [OAuthScope] = [.repo, .readOrg, .project],
        server: GitHubServer = .dotCom,
        store: (any CredentialStore)? = nil,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.clientID = clientID
        self.scopes = scopes
        self.server = server
        self.transport = transport
        #if canImport(Security)
            self.store = store ?? KeychainCredentialStore(service: Bundle.main.bundleIdentifier ?? "GHKit")
        #else
            self.store = store ?? InMemoryCredentialStore()
        #endif
    }

    public var isSignedIn: Bool { if case .signedIn = state { true } else { false } }

    public var user: User? { if case .signedIn(let user) = state { user } else { nil } }

    // MARK: Sign in and out

    /// Loads a saved token and checks it. Call once at launch.
    public func restore() async {
        guard case .restoring = state else { return }
        guard let credential = try? await store.load() else {
            state = .signedOut
            return
        }
        do {
            try await activate(credential)
        } catch {
            // A revoked or expired token: start over.
            try? await store.delete()
            state = .signedOut
        }
    }

    /// Starts device flow in a task the session owns. Cancel with ``cancelSignIn()``.
    public func startDeviceFlowSignIn() {
        signInTask?.cancel()
        signInTask = Task { await signInWithDeviceFlow() }
    }

    /// Runs device flow to completion. Cancelling the calling task stops it.
    public func signInWithDeviceFlow() async {
        lastError = nil
        let flow = DeviceFlow(clientID: clientID, scopes: scopes, server: server, transport: transport)
        do {
            let authorization = try await flow.start()
            state = .awaitingAuthorization(authorization)
            let credential = try await flow.waitForAuthorization(authorization)
            try await activate(credential)
            try? await store.save(credential)
        } catch {
            fail(error)
        }
    }

    public func cancelSignIn() {
        signInTask?.cancel()
        signInTask = nil
        if case .awaitingAuthorization = state { state = .signedOut }
    }

    /// Signs in with a personal access token, for example in a settings screen.
    public func signIn(token: String) async throws(GitHubError) {
        try await signIn(credential: OAuthCredential(accessToken: token))
    }

    /// Signs in with a credential from another flow, such as ``/GHKit/OAuthWebFlow``.
    public func signIn(credential: OAuthCredential) async throws(GitHubError) {
        lastError = nil
        do {
            try await activate(credential)
            try? await store.save(credential)
        } catch {
            fail(error)
            throw error
        }
    }

    /// Forgets the token on this device. It stays valid on GitHub until it's revoked
    /// (see `OAuthApplicationAPI.deleteToken(_:)`) or expires.
    public func signOut() async {
        cancelSignIn()
        try? await store.delete()
        client = nil
        grantedScopes = nil
        rateLimit = nil
        state = .signedOut
    }

    // MARK: Private

    private func activate(_ credential: OAuthCredential) async throws(GitHubError) {
        let authenticator = OAuthAuthenticator(
            credential: credential,
            refresh: .init(clientID: clientID, server: server),
            store: store,
            transport: transport
        )
        let configuration = GitHubConfiguration(
            server: server,
            onResponse: { [weak self] metadata in
                guard let rateLimit = metadata.rateLimit else { return }
                Task { @MainActor in self?.rateLimit = rateLimit }
            })
        let client = GitHubClient(authenticator: authenticator, configuration: configuration, transport: transport)
        let status = try await client.verifyAuthentication()
        self.client = client
        self.grantedScopes = status.scopes
        self.rateLimit = status.rateLimit
        self.state = .signedIn(status.user)
    }

    private func fail(_ error: GitHubError) {
        if case .cancelled = error {
            if case .awaitingAuthorization = state { state = .signedOut }
            return
        }
        lastError = error
        if !isSignedIn { state = .signedOut }
    }
}
