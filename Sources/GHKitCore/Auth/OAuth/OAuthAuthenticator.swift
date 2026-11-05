import Foundation

/// Authenticates with a user access token from an OAuth app or a GitHub App,
/// refreshing it automatically when it expires.
///
/// Concurrent requests share one refresh. Pass a ``CredentialStore`` to persist
/// refreshed tokens, for example ``KeychainCredentialStore``.
///
///     let auth = OAuthAuthenticator(
///         credential: credential,
///         refresh: .init(clientID: "Iv1.abc"),
///         store: KeychainCredentialStore(service: "com.example.app")
///     )
///     let github = GitHubClient(authenticator: auth)
public actor OAuthAuthenticator: Authenticator {
    /// What the authenticator needs to refresh expiring tokens.
    public struct RefreshConfiguration: Sendable {
        public var clientID: String
        /// Required by GitHub for refreshes from a server. Leave `nil` in apps.
        public var clientSecret: String?
        public var server: GitHubServer

        public init(clientID: String, clientSecret: String? = nil, server: GitHubServer = .dotCom) {
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.server = server
        }
    }

    public private(set) var credential: OAuthCredential
    private let refreshConfiguration: RefreshConfiguration?
    private let store: (any CredentialStore)?
    private let transport: any HTTPTransport
    private var refreshTask: Task<OAuthCredential, any Error>?
    private var continuations: [UUID: AsyncStream<OAuthCredential?>.Continuation] = [:]

    public init(
        credential: OAuthCredential,
        refresh: RefreshConfiguration? = nil,
        store: (any CredentialStore)? = nil,
        transport: some HTTPTransport = URLSessionTransport()
    ) {
        self.credential = credential
        self.refreshConfiguration = refresh
        self.store = store
        self.transport = transport
    }

    public func authorization() async throws(GitHubError) -> String? {
        if credential.isExpired(), credential.canRefresh(), refreshConfiguration != nil {
            // Use the returned credential: another caller may still be storing it.
            return "Bearer \(try await refresh().accessToken)"
        }
        return "Bearer \(credential.accessToken)"
    }

    public func refreshAfterUnauthorized() async throws(GitHubError) -> Bool {
        guard credential.canRefresh(), refreshConfiguration != nil else { return false }
        try await refresh()
        return true
    }

    /// Refreshes now. Concurrent callers wait on the same refresh.
    @discardableResult
    public func refresh() async throws(GitHubError) -> OAuthCredential {
        if let refreshTask { return try await Self.await(refreshTask) }

        guard let config = refreshConfiguration, let refreshToken = credential.refreshToken else {
            throw .authentication("This credential can't be refreshed.")
        }
        let endpoints = OAuthEndpoints(server: config.server, transport: transport)
        let task = Task<OAuthCredential, any Error> {
            try await endpoints.refresh(refreshToken, clientID: config.clientID, clientSecret: config.clientSecret)
        }
        refreshTask = task
        defer { refreshTask = nil }

        let updated = try await Self.await(task)
        credential = updated
        try? await store?.save(updated)
        broadcast(updated)
        return updated
    }

    /// Emits the credential after each refresh, and `nil` after ``signOut()``.
    public func credentialUpdates() -> AsyncStream<OAuthCredential?> {
        let (stream, continuation) = AsyncStream<OAuthCredential?>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    /// Deletes the stored credential. Revoke the token on GitHub separately if needed.
    public func signOut() async {
        try? await store?.delete()
        broadcast(nil)
    }

    private func broadcast(_ credential: OAuthCredential?) {
        for continuation in continuations.values { continuation.yield(credential) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private static func await(_ task: Task<OAuthCredential, any Error>) async throws(GitHubError) -> OAuthCredential {
        do {
            return try await task.value
        } catch let error as GitHubError {
            throw error
        } catch {
            throw .transport(error)
        }
    }
}
