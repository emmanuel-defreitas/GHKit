import Foundation
import GHKitCore

extension GitHubClient {
    /// GitHub App endpoints used for authentication.
    public var apps: AppsAPI { AppsAPI(client: self) }

    /// Token management for an OAuth app or GitHub App. These endpoints use Basic
    /// authentication with the app's client ID and secret, so call them from a server.
    public func oauthApplication(clientID: String, clientSecret: String) -> OAuthApplicationAPI {
        OAuthApplicationAPI(
            client: with(authenticator: BasicAuthenticator(username: clientID, password: clientSecret)),
            clientID: clientID
        )
    }
}

/// GitHub App endpoints. Reach them with `github.apps`.
///
/// Endpoints marked "app JWT" need a client using ``GitHubAppAuthenticator``.
///
/// Part of the `GHKitApps` library.
public struct AppsAPI: Sendable {
    let client: GitHubClient

    /// The app the JWT belongs to (app JWT). `GET /app`
    public func authenticatedApp() async throws(GitHubError) -> GitHubApp {
        try await client.value(GitHubRequest(.get, "/app"))
    }

    /// A public app by its slug. `GET /apps/{app_slug}`
    public func app(slug: String) async throws(GitHubError) -> GitHubApp {
        try await client.value(GitHubRequest(.get, "/apps/\(escape(slug))"))
    }

    /// Every installation of the app (app JWT). `GET /app/installations`
    public func installations(perPage: Int = 100) -> Paginated<Installation> {
        client.paginate(GitHubRequest(.get, "/app/installations", query: .query(("per_page", perPage))))
    }

    /// One installation (app JWT). `GET /app/installations/{installation_id}`
    public func installation(id: Int) async throws(GitHubError) -> Installation {
        try await client.value(GitHubRequest(.get, "/app/installations/\(id)"))
    }

    /// The app's installation on an organization (app JWT). `GET /orgs/{org}/installation`
    public func installation(organization: String) async throws(GitHubError) -> Installation {
        try await client.value(GitHubRequest(.get, "/orgs/\(escape(organization))/installation"))
    }

    /// The app's installation on a user account (app JWT). `GET /users/{username}/installation`
    public func installation(user: String) async throws(GitHubError) -> Installation {
        try await client.value(GitHubRequest(.get, "/users/\(escape(user))/installation"))
    }

    /// The installation that covers a repository (app JWT). `GET /repos/{owner}/{repo}/installation`
    public func installation(owner: String, repository: String) async throws(GitHubError) -> Installation {
        try await client.value(GitHubRequest(.get, "/repos/\(escape(owner))/\(escape(repository))/installation"))
    }

    /// Mints an installation token (app JWT). `POST /app/installations/{installation_id}/access_tokens`
    ///
    /// ``InstallationAuthenticator`` calls this for you and caches the result.
    public func createInstallationAccessToken(
        installationID: Int,
        options: InstallationTokenOptions = InstallationTokenOptions()
    ) async throws(GitHubError) -> InstallationToken {
        try await client.value(GitHubRequest(.post, "/app/installations/\(installationID)/access_tokens", body: options))
    }

    /// Revokes the installation token the client is using. `DELETE /installation/token`
    public func revokeInstallationAccessToken() async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/installation/token"))
    }

    /// Uninstalls the app (app JWT). `DELETE /app/installations/{installation_id}`
    public func deleteInstallation(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/app/installations/\(id)"))
    }

    /// Suspends an installation (app JWT). `PUT /app/installations/{installation_id}/suspended`
    public func suspendInstallation(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, "/app/installations/\(id)/suspended"))
    }

    /// Lifts a suspension (app JWT). `DELETE /app/installations/{installation_id}/suspended`
    public func unsuspendInstallation(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/app/installations/\(id)/suspended"))
    }

    /// Installations the signed-in user can access (user token). `GET /user/installations`
    public func installationsForAuthenticatedUser(perPage: Int = 100) -> Paginated<Installation> {
        client.paginate(.wrappedList("/user/installations", key: "installations", query: .query(("per_page", perPage))))
    }
}

/// Token management for an OAuth app. Get one with
/// `github.oauthApplication(clientID:clientSecret:)`.
///
/// Part of the `GHKitApps` library.
public struct OAuthApplicationAPI: Sendable {
    let client: GitHubClient
    public let clientID: String

    private struct TokenBody: Encodable, Sendable {
        let access_token: String
    }

    /// Checks a token and returns its details, or throws `.notFound` if it's invalid.
    /// `POST /applications/{client_id}/token`
    public func checkToken(_ accessToken: String) async throws(GitHubError) -> OAuthAuthorization {
        try await client.value(GitHubRequest(.post, "/applications/\(escape(clientID))/token", body: TokenBody(access_token: accessToken)))
    }

    /// Replaces a token with a new one. `PATCH /applications/{client_id}/token`
    public func resetToken(_ accessToken: String) async throws(GitHubError) -> OAuthAuthorization {
        try await client.value(GitHubRequest(.patch, "/applications/\(escape(clientID))/token", body: TokenBody(access_token: accessToken)))
    }

    /// Revokes one token. Use it on sign-out. `DELETE /applications/{client_id}/token`
    public func deleteToken(_ accessToken: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/applications/\(escape(clientID))/token", body: TokenBody(access_token: accessToken)))
    }

    /// Revokes the user's whole grant: every token for this app.
    /// `DELETE /applications/{client_id}/grant`
    public func deleteGrant(_ accessToken: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/applications/\(escape(clientID))/grant", body: TokenBody(access_token: accessToken)))
    }
}
