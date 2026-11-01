import Foundation

/// A GitHub App's identity: its client ID (or numeric app ID) and private key.
public struct GitHubAppCredentials: Sendable, Hashable {
    /// The JWT issuer. GitHub recommends the client ID; the app ID also works.
    public var issuer: String
    public var privateKey: RSAPrivateKey

    public init(issuer: String, privateKey: RSAPrivateKey) {
        self.issuer = issuer
        self.privateKey = privateKey
    }

    public init(issuer: String, privateKeyPEM: String) throws(GitHubError) {
        self.init(issuer: issuer, privateKey: try RSAPrivateKey(pem: privateKeyPEM))
    }

    #if canImport(Security)
        /// Makes a JWT for authenticating as the app.
        ///
        /// It's backdated 60 seconds against clock drift and lasts 9 minutes,
        /// under GitHub's 10-minute limit.
        public func makeJWT(now: Date = .now, lifetime: Duration = .seconds(540)) throws(GitHubError) -> String {
            let issuedAt = Int(now.timeIntervalSince1970) - 60
            let expiresAt = Int(now.timeIntervalSince1970 + lifetime.timeInterval)
            let header = #"{"alg":"RS256","typ":"JWT"}"#
            let issuerJSON = String(data: (try? JSONEncoder().encode(issuer)) ?? Data(), encoding: .utf8) ?? "\"\""
            let payload = #"{"iat":\#(issuedAt),"exp":\#(expiresAt),"iss":\#(issuerJSON)}"#
            let signingInput = Data(header.utf8).base64URLEncodedString() + "." + Data(payload.utf8).base64URLEncodedString()
            let signature = try privateKey.signRS256(Data(signingInput.utf8))
            return signingInput + "." + signature.base64URLEncodedString()
        }
    #endif
}

#if canImport(Security)
    /// Authenticates as the GitHub App itself, using a JWT.
    ///
    /// Use it for app-level endpoints such as `GET /app` and `GET /app/installations`.
    /// For anything that acts on an installation's resources, use ``InstallationAuthenticator``.
    public actor GitHubAppAuthenticator: Authenticator {
        public let credentials: GitHubAppCredentials
        private var cached: (token: String, expiresAt: Date)?

        public init(credentials: GitHubAppCredentials) {
            self.credentials = credentials
        }

        public func authorization() async throws(GitHubError) -> String? {
            let now = Date.now
            if let cached, cached.expiresAt.timeIntervalSince(now) > 60 {
                return "Bearer \(cached.token)"
            }
            let token = try credentials.makeJWT(now: now)
            cached = (token, now.addingTimeInterval(540))
            return "Bearer \(token)"
        }

        public func refreshAfterUnauthorized() async throws(GitHubError) -> Bool {
            guard cached != nil else { return false }
            cached = nil
            return true
        }
    }

    /// Authenticates as one installation of a GitHub App.
    ///
    /// Mints installation tokens as needed, caches them until shortly before they
    /// expire (they last 1 hour), and shares one fetch between concurrent requests.
    ///
    ///     let app = try GitHubAppCredentials(issuer: "Iv23li…", privateKeyPEM: pem)
    ///     let github = GitHubClient(authenticator: InstallationAuthenticator(app: app, installationID: 42))
    public actor InstallationAuthenticator: Authenticator {
        public let installationID: Int
        private let options: InstallationTokenOptions
        private let appClient: GitHubClient
        private var token: InstallationToken?
        private var pending: Task<InstallationToken, any Error>?

        public init(
            app: GitHubAppCredentials,
            installationID: Int,
            options: InstallationTokenOptions = InstallationTokenOptions(),
            configuration: GitHubConfiguration = GitHubConfiguration(),
            transport: some HTTPTransport = URLSessionTransport()
        ) {
            self.installationID = installationID
            self.options = options
            self.appClient = GitHubClient(
                authenticator: GitHubAppAuthenticator(credentials: app),
                configuration: configuration,
                transport: transport
            )
        }

        public func authorization() async throws(GitHubError) -> String? {
            "Bearer \(try await currentToken().token)"
        }

        public func refreshAfterUnauthorized() async throws(GitHubError) -> Bool {
            token = nil
            _ = try await currentToken()
            return true
        }

        /// The cached token, or a fresh one if it expires within 5 minutes.
        public func currentToken() async throws(GitHubError) -> InstallationToken {
            if let token, token.expiresAt.timeIntervalSinceNow > 300 { return token }
            if let pending { return try await Self.await(pending) }

            let client = appClient
            let id = installationID
            let options = options
            let task = Task<InstallationToken, any Error> {
                try await client.apps.createInstallationAccessToken(installationID: id, options: options)
            }
            pending = task
            defer { pending = nil }
            let fresh = try await Self.await(task)
            token = fresh
            return fresh
        }

        private static func await(_ task: Task<InstallationToken, any Error>) async throws(GitHubError) -> InstallationToken {
            do {
                return try await task.value
            } catch let error as GitHubError {
                throw error
            } catch {
                throw .transport(error)
            }
        }
    }
#endif
