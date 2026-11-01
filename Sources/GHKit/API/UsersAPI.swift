import Foundation

extension GitHubClient {
    /// User endpoints.
    public var users: UsersAPI { UsersAPI(client: self) }

    /// Confirms the credentials work and reports who they belong to and what they allow.
    ///
    /// Good for "signed in as …" UI and for checking scopes before a call.
    public func verifyAuthentication() async throws(GitHubError) -> AuthenticationStatus {
        let response = try await send(GitHubRequest<User>(.get, "/user"))
        return AuthenticationStatus(
            user: response.value,
            scopes: response.metadata.oauthScopes,
            tokenExpiresAt: response.metadata.tokenExpiration,
            rateLimit: response.metadata.rateLimit
        )
    }

    /// Current rate limits for every bucket. This call doesn't count against them.
    public func rateLimit() async throws(GitHubError) -> RateLimitOverview {
        try await value(GitHubRequest(.get, "/rate_limit"))
    }
}

/// User endpoints. Reach them with `github.users`.
public struct UsersAPI: Sendable {
    let client: GitHubClient

    /// The signed-in user. `GET /user`
    public func authenticated() async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/user"))
    }

    /// A user or organization by login. `GET /users/{username}`
    public func user(_ login: String) async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/users/\(escape(login))"))
    }

    /// A user by numeric ID, which survives renames. `GET /user/{account_id}`
    public func user(id: Int) async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/user/\(id)"))
    }
}
