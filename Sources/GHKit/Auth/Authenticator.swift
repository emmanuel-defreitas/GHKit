import Foundation

/// Supplies the `Authorization` header for each request.
///
/// GHKit ships authenticators for every GitHub credential type:
/// - ``TokenAuthenticator``: personal access tokens and any fixed token
/// - ``OAuthAuthenticator``: OAuth / GitHub App user tokens, with automatic refresh
/// - ``GitHubAppAuthenticator``: GitHub App JWTs, for `/app` endpoints
/// - ``InstallationAuthenticator``: GitHub App installation tokens, minted and cached
/// - ``BasicAuthenticator``: OAuth app client ID and secret, for `/applications` endpoints
public protocol Authenticator: Sendable {
    /// The full header value, such as `"Bearer ghp_…"`, or `nil` for anonymous requests.
    func authorization() async throws(GitHubError) -> String?

    /// Called once after a `401`. Return `true` if new credentials are ready and
    /// the request should be retried.
    func refreshAfterUnauthorized() async throws(GitHubError) -> Bool
}

extension Authenticator {
    public func refreshAfterUnauthorized() async throws(GitHubError) -> Bool { false }
}

/// Sends no credentials. Anonymous requests get a low rate limit (60 per hour).
public struct AnonymousAuthenticator: Authenticator {
    public init() {}
    public func authorization() async throws(GitHubError) -> String? { nil }
}

/// Sends a fixed token: a fine-grained or classic personal access token,
/// an OAuth token, or an installation token you manage yourself.
public struct TokenAuthenticator: Authenticator {
    public let token: String

    public init(token: String) {
        self.token = token
    }

    public func authorization() async throws(GitHubError) -> String? { "Bearer \(token)" }
}

/// HTTP Basic authentication. GitHub requires it, with an OAuth app's client ID and
/// secret, for the `/applications/{client_id}/...` token management endpoints.
public struct BasicAuthenticator: Authenticator {
    public let username: String
    let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func authorization() async throws(GitHubError) -> String? {
        "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
    }
}

extension Authenticator where Self == AnonymousAuthenticator {
    public static var anonymous: AnonymousAuthenticator { AnonymousAuthenticator() }
}

extension Authenticator where Self == TokenAuthenticator {
    public static func token(_ token: String) -> TokenAuthenticator { TokenAuthenticator(token: token) }
}
