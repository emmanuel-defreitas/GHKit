import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

/// OAuth web application flow, with PKCE.
///
/// 1. Call ``makeAuthorizationRequest(login:allowSignup:)`` and open its URL, for example
///    with SwiftUI's `webAuthenticationSession` (see `GHKitUI`).
/// 2. Pass the callback URL to ``exchange(callbackURL:for:)``.
///
/// GitHub still requires the client secret for the code exchange. Don't ship a secret
/// in an app binary: run the exchange on your server, or use ``DeviceFlow`` instead.
public struct OAuthWebFlow: Sendable {
    public let clientID: String
    let clientSecret: String?
    public let redirectURI: URL
    public let scopes: [OAuthScope]
    let endpoints: OAuthEndpoints

    public init(
        clientID: String,
        clientSecret: String?,
        redirectURI: URL,
        scopes: [OAuthScope] = [],
        server: GitHubServer = .dotCom,
        transport: some HTTPTransport = URLSessionTransport()
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.endpoints = OAuthEndpoints(server: server, transport: transport)
    }

    /// Builds the authorize URL with a random `state` and a PKCE challenge.
    ///
    /// - Parameters:
    ///   - login: Suggests an account on the sign-in page.
    ///   - allowSignup: Whether unauthenticated users may create an account.
    public func makeAuthorizationRequest(login: String? = nil, allowSignup: Bool? = nil) -> AuthorizationRequest {
        let state = Self.randomURLSafeString(byteCount: 16)
        let verifier = PKCE.makeVerifier()
        var components = URLComponents(
            url: endpoints.server.webURL.appending(path: "login/oauth/authorize"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        if !scopes.isEmpty { items.append(URLQueryItem(name: "scope", value: scopes.map(\.rawValue).joined(separator: " "))) }
        if let login { items.append(URLQueryItem(name: "login", value: login)) }
        if let allowSignup { items.append(URLQueryItem(name: "allow_signup", value: String(allowSignup))) }
        components.queryItems = items
        return AuthorizationRequest(url: components.url!, state: state, codeVerifier: verifier)
    }

    /// Checks the callback against the request, then trades the code for a token.
    public func exchange(callbackURL: URL, for request: AuthorizationRequest) async throws(GitHubError) -> OAuthCredential {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        if let error = value("error") {
            throw .oauth(
                OAuthError(
                    code: .init(error),
                    message: value("error_description"),
                    documentationURL: value("error_uri").flatMap(URL.init(string:))
                ))
        }
        guard value("state") == request.state else {
            throw .authentication("The OAuth state didn't match. The callback may not be from this sign-in.")
        }
        guard let code = value("code") else {
            throw .authentication("The callback URL has no authorization code.")
        }
        return try await exchange(code: code, codeVerifier: request.codeVerifier)
    }

    /// Trades an authorization code for a token.
    public func exchange(code: String, codeVerifier: String?) async throws(GitHubError) -> OAuthCredential {
        var form = ["client_id": clientID, "code": code, "redirect_uri": redirectURI.absoluteString]
        form["client_secret"] = clientSecret
        form["code_verifier"] = codeVerifier
        return try await endpoints.token(form: form)
    }

    /// Exchanges a refresh token for a new credential (GitHub App user tokens only).
    public func refresh(_ credential: OAuthCredential) async throws(GitHubError) -> OAuthCredential {
        guard let refreshToken = credential.refreshToken else {
            throw .authentication("This credential has no refresh token.")
        }
        return try await endpoints.refresh(refreshToken, clientID: clientID, clientSecret: clientSecret)
    }

    static func randomURLSafeString(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64URLEncodedString()
    }
}

/// The state you keep between opening the authorize URL and handling the callback.
public struct AuthorizationRequest: Sendable, Hashable, Codable {
    public let url: URL
    public let state: String
    public let codeVerifier: String
}

/// PKCE helpers (RFC 7636).
public enum PKCE {
    /// A random 43-character code verifier.
    public static func makeVerifier() -> String {
        OAuthWebFlow.randomURLSafeString(byteCount: 32)
    }

    /// The S256 challenge for a verifier.
    public static func challenge(for verifier: String) -> String {
        #if canImport(CryptoKit)
            Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        #else
            fatalError("PKCE needs CryptoKit")
        #endif
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
