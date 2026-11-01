import Foundation

/// OAuth device flow: the best sign-in option for native apps, because it needs
/// no client secret and no redirect URL.
///
/// 1. Call ``start()`` and show the user ``DeviceAuthorization/userCode``.
/// 2. Send them to ``DeviceAuthorization/verificationURL`` to enter it.
/// 3. Await ``waitForAuthorization(_:)`` to get the token.
///
///     let flow = DeviceFlow(clientID: "Iv1.abc", scopes: [.repo, .project])
///     let authorization = try await flow.start()
///     show(authorization.userCode)
///     let credential = try await flow.waitForAuthorization(authorization)
///     let github = GitHubClient(authenticator: OAuthAuthenticator(credential: credential))
///
/// Enable device flow in the OAuth app or GitHub App settings first.
public struct DeviceFlow: Sendable {
    public let clientID: String
    public let scopes: [OAuthScope]
    let endpoints: OAuthEndpoints
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    var now: @Sendable () -> Date = { .now }

    /// - Parameters:
    ///   - clientID: The OAuth app or GitHub App client ID.
    ///   - scopes: OAuth app scopes. GitHub Apps ignore this and use their configured permissions.
    public init(
        clientID: String,
        scopes: [OAuthScope] = [],
        server: GitHubServer = .dotCom,
        transport: some HTTPTransport = URLSessionTransport()
    ) {
        self.clientID = clientID
        self.scopes = scopes
        self.endpoints = OAuthEndpoints(server: server, transport: transport)
    }

    /// Requests a user code. Codes last 15 minutes.
    public func start() async throws(GitHubError) -> DeviceAuthorization {
        var form = ["client_id": clientID]
        if !scopes.isEmpty { form["scope"] = scopes.map(\.rawValue).joined(separator: " ") }
        let response: DeviceCodeResponse = try await endpoints.post("login/device/code", form: form)
        return DeviceAuthorization(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURL: response.verificationURI,
            expiresAt: now().addingTimeInterval(TimeInterval(response.expiresIn)),
            interval: .seconds(response.interval ?? 5)
        )
    }

    /// Polls until the user approves or denies, or the code expires.
    ///
    /// Respects GitHub's polling interval and `slow_down` responses. Cancel the task to stop.
    public func waitForAuthorization(_ authorization: DeviceAuthorization) async throws(GitHubError) -> OAuthCredential {
        var interval = authorization.interval
        while true {
            do { try await sleep(interval) } catch { throw .cancelled }
            if now() >= authorization.expiresAt {
                throw .oauth(OAuthError(code: .expiredToken))
            }
            do {
                return try await endpoints.token(form: [
                    "client_id": clientID,
                    "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ])
            } catch .oauth(let error) where error.code == .authorizationPending {
                continue
            } catch .oauth(let error) where error.code == .slowDown {
                // GitHub asks for 5 more seconds each time.
                interval += .seconds(5)
                continue
            }
        }
    }

    /// Runs both steps. `onCode` is called with the code to show the user.
    public func authenticate(
        onCode: @Sendable (DeviceAuthorization) async -> Void
    ) async throws(GitHubError) -> OAuthCredential {
        let authorization = try await start()
        await onCode(authorization)
        return try await waitForAuthorization(authorization)
    }
}

/// What to show the user during device flow.
public struct DeviceAuthorization: Sendable, Hashable {
    /// Secret code for polling. Don't show it to the user.
    public let deviceCode: String
    /// The code the user types on GitHub, such as `WDJB-MJHT`.
    public let userCode: String
    /// Where the user enters the code, normally `https://github.com/login/device`.
    public let verificationURL: URL
    public let expiresAt: Date
    public let interval: Duration
}

private struct DeviceCodeResponse: Decodable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let expiresIn: Int
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case interval
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
    }
}
