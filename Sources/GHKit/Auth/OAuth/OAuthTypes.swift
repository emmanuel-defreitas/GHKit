import Foundation

/// An OAuth scope, such as `repo` or `read:project`.
///
/// Fine-grained tokens and GitHub Apps use permissions instead of scopes.
public struct OAuthScope: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }

    static func parseList(_ list: String) -> [OAuthScope] {
        list.split(whereSeparator: { $0 == "," || $0 == " " }).map { OAuthScope(String($0)) }
    }

    // Repositories
    public static let repo: OAuthScope = "repo"
    public static let repoStatus: OAuthScope = "repo:status"
    public static let repoDeployment: OAuthScope = "repo_deployment"
    public static let publicRepo: OAuthScope = "public_repo"
    public static let repoInvite: OAuthScope = "repo:invite"
    public static let securityEvents: OAuthScope = "security_events"
    public static let deleteRepo: OAuthScope = "delete_repo"
    public static let workflow: OAuthScope = "workflow"
    // Webhooks
    public static let adminRepoHook: OAuthScope = "admin:repo_hook"
    public static let writeRepoHook: OAuthScope = "write:repo_hook"
    public static let readRepoHook: OAuthScope = "read:repo_hook"
    public static let adminOrgHook: OAuthScope = "admin:org_hook"
    // Organizations and teams
    public static let adminOrg: OAuthScope = "admin:org"
    public static let writeOrg: OAuthScope = "write:org"
    public static let readOrg: OAuthScope = "read:org"
    // Projects
    public static let project: OAuthScope = "project"
    public static let readProject: OAuthScope = "read:project"
    // Users
    public static let user: OAuthScope = "user"
    public static let readUser: OAuthScope = "read:user"
    public static let userEmail: OAuthScope = "user:email"
    public static let userFollow: OAuthScope = "user:follow"
    // Keys
    public static let adminPublicKey: OAuthScope = "admin:public_key"
    public static let adminGPGKey: OAuthScope = "admin:gpg_key"
    public static let adminSSHSigningKey: OAuthScope = "admin:ssh_signing_key"
    // Everything else
    public static let gist: OAuthScope = "gist"
    public static let notifications: OAuthScope = "notifications"
    public static let readPackages: OAuthScope = "read:packages"
    public static let writePackages: OAuthScope = "write:packages"
    public static let deletePackages: OAuthScope = "delete:packages"
    public static let codespace: OAuthScope = "codespace"
    public static let copilot: OAuthScope = "copilot"
    public static let readAuditLog: OAuthScope = "read:audit_log"
    public static let adminEnterprise: OAuthScope = "admin:enterprise"
}

/// A user access token from an OAuth app or a GitHub App, as stored by your app.
public struct OAuthCredential: Sendable, Hashable, Codable {
    public var accessToken: String
    public var tokenType: String
    public var scopes: [OAuthScope]
    /// Set for GitHub App user tokens that expire (8 hours by default).
    public var expiresAt: Date?
    public var refreshToken: String?
    public var refreshTokenExpiresAt: Date?
    public var issuedAt: Date

    public init(
        accessToken: String,
        tokenType: String = "bearer",
        scopes: [OAuthScope] = [],
        expiresAt: Date? = nil,
        refreshToken: String? = nil,
        refreshTokenExpiresAt: Date? = nil,
        issuedAt: Date = .now
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.scopes = scopes
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.issuedAt = issuedAt
    }

    /// Whether the access token expires within `margin` of `date`.
    public func isExpired(at date: Date = .now, margin: Duration = .seconds(60)) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(date) <= margin.timeInterval
    }

    /// Whether a usable refresh token is present.
    public func canRefresh(at date: Date = .now) -> Bool {
        guard refreshToken != nil else { return false }
        guard let refreshTokenExpiresAt else { return true }
        return refreshTokenExpiresAt > date
    }
}

/// An error from GitHub's OAuth endpoints.
public struct OAuthError: Error, Sendable, Hashable {
    public var code: Code
    public var message: String?
    public var documentationURL: URL?

    public init(code: Code, message: String? = nil, documentationURL: URL? = nil) {
        self.code = code
        self.message = message
        self.documentationURL = documentationURL
    }

    public enum Code: Sendable, Hashable {
        case authorizationPending
        case slowDown
        case expiredToken
        case accessDenied
        case incorrectClientCredentials
        case incorrectDeviceCode
        case deviceFlowDisabled
        case unsupportedGrantType
        case badVerificationCode
        case badRefreshToken
        case redirectURIMismatch
        case applicationSuspended
        case other(String)

        init(_ raw: String) {
            self =
                switch raw {
                case "authorization_pending": .authorizationPending
                case "slow_down": .slowDown
                case "expired_token", "token_expired": .expiredToken
                case "access_denied": .accessDenied
                case "incorrect_client_credentials": .incorrectClientCredentials
                case "incorrect_device_code": .incorrectDeviceCode
                case "device_flow_disabled": .deviceFlowDisabled
                case "unsupported_grant_type": .unsupportedGrantType
                case "bad_verification_code": .badVerificationCode
                case "bad_refresh_token": .badRefreshToken
                case "redirect_uri_mismatch": .redirectURIMismatch
                case "application_suspended": .applicationSuspended
                default: .other(raw)
                }
        }
    }

    public var errorDescription: String {
        if let message { return message }
        return switch code {
        case .authorizationPending: "Waiting for the user to authorize."
        case .slowDown: "Polling too fast."
        case .expiredToken: "The code expired. Start sign-in again."
        case .accessDenied: "Access was denied."
        case .incorrectClientCredentials: "The client ID or secret is wrong."
        case .incorrectDeviceCode: "The device code is invalid."
        case .deviceFlowDisabled: "Device flow is not enabled for this app."
        case .unsupportedGrantType: "Unsupported grant type."
        case .badVerificationCode: "The authorization code is invalid or expired."
        case .badRefreshToken: "The refresh token is invalid or expired."
        case .redirectURIMismatch: "The redirect URI doesn't match the app's settings."
        case .applicationSuspended: "The app is suspended."
        case .other(let raw): raw
        }
    }
}

/// The raw response from `/login/oauth/access_token` and `/login/device/code`.
struct OAuthTokenResponse: Decodable {
    var accessToken: String?
    var tokenType: String?
    var scope: String?
    var expiresIn: Int?
    var refreshToken: String?
    var refreshTokenExpiresIn: Int?
    var error: String?
    var errorDescription: String?
    var errorURI: URL?
    var interval: Int?

    enum CodingKeys: String, CodingKey {
        case scope, error, interval
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case errorDescription = "error_description"
        case errorURI = "error_uri"
    }

    var oauthError: OAuthError? {
        error.map { OAuthError(code: .init($0), message: errorDescription, documentationURL: errorURI) }
    }

    func credential(issuedAt now: Date = .now) throws(GitHubError) -> OAuthCredential {
        if let oauthError { throw .oauth(oauthError) }
        guard let accessToken else { throw .authentication("GitHub didn't return an access token.") }
        return OAuthCredential(
            accessToken: accessToken,
            tokenType: tokenType ?? "bearer",
            scopes: scope.map(OAuthScope.parseList) ?? [],
            expiresAt: expiresIn.map { now.addingTimeInterval(TimeInterval($0)) },
            refreshToken: refreshToken.flatMap { $0.isEmpty ? nil : $0 },
            refreshTokenExpiresAt: refreshTokenExpiresIn.map { now.addingTimeInterval(TimeInterval($0)) },
            issuedAt: now
        )
    }
}

/// Calls the OAuth endpoints on the GitHub website (not the API host).
struct OAuthEndpoints: Sendable {
    let server: GitHubServer
    let transport: any HTTPTransport

    func post<Response: Decodable & Sendable>(
        _ path: String,
        form: [String: String],
        as type: Response.Type = Response.self
    ) async throws(GitHubError) -> Response {
        let client = GitHubClient(
            configuration: GitHubConfiguration(server: server, retryPolicy: .none),
            transport: transport
        )
        var request = GitHubRequest<Response>(
            method: .post,
            target: .url(server.webURL.appending(path: path)),
            body: .form(form),
            decode: { data in try GitHubJSON.decoder().decode(Response.self, from: data) }
        )
        request.headers["Accept"] = "application/json"
        let urlRequest = try client.makeURLRequest(for: request)

        let data: Data
        let http: HTTPURLResponse
        do {
            (data, http) = try await transport.send(urlRequest)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .transport(error)
        }

        // OAuth endpoints put `{"error": …}` in the body, sometimes with a 200 status
        // and sometimes with a 4xx, so check the body first.
        if let failure = try? GitHubJSON.decoder().decode(OAuthTokenResponse.self, from: data),
            let oauthError = failure.oauthError
        {
            throw .oauth(oauthError)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubError.from(status: http.statusCode, data: data, metadata: ResponseMetadata(http))
        }
        do {
            return try GitHubJSON.decoder().decode(Response.self, from: data)
        } catch {
            throw .decoding(type: String(describing: Response.self), underlying: error)
        }
    }

    func token(form: [String: String]) async throws(GitHubError) -> OAuthCredential {
        let response: OAuthTokenResponse = try await post("login/oauth/access_token", form: form)
        return try response.credential()
    }

    func refresh(
        _ refreshToken: String,
        clientID: String,
        clientSecret: String?
    ) async throws(GitHubError) -> OAuthCredential {
        var form = ["client_id": clientID, "grant_type": "refresh_token", "refresh_token": refreshToken]
        form["client_secret"] = clientSecret
        return try await token(form: form)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
