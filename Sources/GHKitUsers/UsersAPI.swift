import Foundation
import GHKitCore

extension GitHubClient {
    /// User endpoints.
    public var users: UsersAPI { UsersAPI(client: scoped(to: .users)) }

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
}

/// User endpoints. Reach them with `github.users`.
///
/// Methods without a login act on the signed-in user.
///
/// Part of the `GHKitUsers` library.
public struct UsersAPI: Sendable {
    let client: GitHubClient

    // MARK: Profiles

    /// The signed-in user. `GET /user`
    public func authenticated() async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/user"))
    }

    /// Updates the signed-in user's profile. `PATCH /user`
    @discardableResult
    public func updateProfile(_ changes: UserProfileUpdate) async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.patch, "/user", body: changes))
    }

    /// A user or organization by login. `GET /users/{username}`
    public func user(_ login: String) async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/users/\(escape(login))"))
    }

    /// A user by numeric ID, which survives renames. `GET /user/{account_id}`
    public func user(id: Int) async throws(GitHubError) -> User {
        try await client.value(GitHubRequest(.get, "/user/\(id)"))
    }

    /// Every user and organization, in sign-up order. `GET /users`
    /// - Parameter since: Only users with an ID greater than this.
    public func all(since: Int? = nil, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/users", query: .query(("since", since), ("per_page", perPage))))
    }

    /// Context lines for a user's hovercard. `GET /users/{username}/hovercard`
    /// - Parameter subject: Adds lines about a specific organization, repository, issue, or pull request.
    public func hovercard(for login: String, about subject: HovercardSubject? = nil) async throws(GitHubError) -> [HovercardContext] {
        struct Response: Decodable, Sendable { let contexts: [HovercardContext] }
        let response: Response = try await client.value(
            GitHubRequest(.get, "/users/\(escape(login))/hovercard", query: subject?.query ?? []))
        return response.contexts
    }

    // MARK: Followers

    /// People following the signed-in user. `GET /user/followers`
    public func followers(perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/user/followers", query: .query(("per_page", perPage))))
    }

    /// People following a user. `GET /users/{username}/followers`
    public func followers(of login: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/followers", query: .query(("per_page", perPage))))
    }

    /// People the signed-in user follows. `GET /user/following`
    public func following(perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/user/following", query: .query(("per_page", perPage))))
    }

    /// People a user follows. `GET /users/{username}/following`
    public func following(of login: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/following", query: .query(("per_page", perPage))))
    }

    /// Whether the signed-in user follows `login`. `GET /user/following/{username}`
    public func isFollowing(_ login: String) async throws(GitHubError) -> Bool {
        try await client.exists("/user/following/\(escape(login))")
    }

    /// Whether `login` follows `target`. `GET /users/{username}/following/{target_user}`
    public func isFollowing(_ target: String, by login: String) async throws(GitHubError) -> Bool {
        try await client.exists("/users/\(escape(login))/following/\(escape(target))")
    }

    /// Follows a user. `PUT /user/following/{username}`
    public func follow(_ login: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, "/user/following/\(escape(login))"))
    }

    /// Unfollows a user. `DELETE /user/following/{username}`
    public func unfollow(_ login: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/following/\(escape(login))"))
    }

    // MARK: Blocking

    /// Users the signed-in user has blocked. `GET /user/blocks`
    public func blockedUsers(perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, "/user/blocks", query: .query(("per_page", perPage))))
    }

    /// Whether the signed-in user has blocked `login`. `GET /user/blocks/{username}`
    public func isBlocked(_ login: String) async throws(GitHubError) -> Bool {
        try await client.exists("/user/blocks/\(escape(login))")
    }

    /// Blocks a user. `PUT /user/blocks/{username}`
    public func block(_ login: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, "/user/blocks/\(escape(login))"))
    }

    /// Unblocks a user. `DELETE /user/blocks/{username}`
    public func unblock(_ login: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/blocks/\(escape(login))"))
    }

    // MARK: Emails

    private struct EmailsBody: Encodable, Sendable { let emails: [String] }

    /// Every email on the signed-in user's account. `GET /user/emails`
    public func emails(perPage: Int = 100) -> Paginated<UserEmail> {
        client.paginate(GitHubRequest(.get, "/user/emails", query: .query(("per_page", perPage))))
    }

    /// The signed-in user's public emails. `GET /user/public_emails`
    public func publicEmails(perPage: Int = 100) -> Paginated<UserEmail> {
        client.paginate(GitHubRequest(.get, "/user/public_emails", query: .query(("per_page", perPage))))
    }

    /// Adds email addresses. GitHub sends each one a verification email. `POST /user/emails`
    @discardableResult
    public func addEmails(_ emails: [String]) async throws(GitHubError) -> [UserEmail] {
        try await client.value(GitHubRequest(.post, "/user/emails", body: EmailsBody(emails: emails)))
    }

    /// Removes email addresses. `DELETE /user/emails`
    public func deleteEmails(_ emails: [String]) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/emails", body: EmailsBody(emails: emails)))
    }

    /// Shows or hides the primary email on the profile. `PATCH /user/email/visibility`
    @discardableResult
    public func setPrimaryEmailVisibility(_ visibility: EmailVisibility) async throws(GitHubError) -> [UserEmail] {
        struct Body: Encodable, Sendable { let visibility: EmailVisibility }
        return try await client.value(GitHubRequest(.patch, "/user/email/visibility", body: Body(visibility: visibility)))
    }

    // MARK: GPG keys

    /// The signed-in user's GPG keys. `GET /user/gpg_keys`
    public func gpgKeys(perPage: Int = 100) -> Paginated<GPGKey> {
        client.paginate(GitHubRequest(.get, "/user/gpg_keys", query: .query(("per_page", perPage))))
    }

    /// A user's GPG keys. `GET /users/{username}/gpg_keys`
    public func gpgKeys(of login: String, perPage: Int = 100) -> Paginated<GPGKey> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/gpg_keys", query: .query(("per_page", perPage))))
    }

    /// One of the signed-in user's GPG keys. `GET /user/gpg_keys/{gpg_key_id}`
    public func gpgKey(id: Int) async throws(GitHubError) -> GPGKey {
        try await client.value(GitHubRequest(.get, "/user/gpg_keys/\(id)"))
    }

    /// Adds a GPG key. `POST /user/gpg_keys`
    /// - Parameter armoredPublicKey: The key in ASCII-armored format.
    public func addGPGKey(armoredPublicKey: String, name: String? = nil) async throws(GitHubError) -> GPGKey {
        struct Body: Encodable, Sendable { let armored_public_key: String; let name: String? }
        return try await client.value(GitHubRequest(.post, "/user/gpg_keys", body: Body(armored_public_key: armoredPublicKey, name: name)))
    }

    /// Removes a GPG key. `DELETE /user/gpg_keys/{gpg_key_id}`
    public func deleteGPGKey(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/gpg_keys/\(id)"))
    }

    // MARK: SSH keys

    /// The signed-in user's SSH authentication keys. `GET /user/keys`
    public func sshKeys(perPage: Int = 100) -> Paginated<SSHKey> {
        client.paginate(GitHubRequest(.get, "/user/keys", query: .query(("per_page", perPage))))
    }

    /// A user's public SSH keys. `GET /users/{username}/keys`
    public func sshKeys(of login: String, perPage: Int = 100) -> Paginated<SSHKey> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/keys", query: .query(("per_page", perPage))))
    }

    /// One of the signed-in user's SSH keys. `GET /user/keys/{key_id}`
    public func sshKey(id: Int) async throws(GitHubError) -> SSHKey {
        try await client.value(GitHubRequest(.get, "/user/keys/\(id)"))
    }

    /// Adds an SSH authentication key. `POST /user/keys`
    /// - Parameter key: The public key, such as `ssh-ed25519 AAAA…`.
    public func addSSHKey(_ key: String, title: String? = nil) async throws(GitHubError) -> SSHKey {
        try await client.value(GitHubRequest(.post, "/user/keys", body: NewKey(key: key, title: title)))
    }

    /// Removes an SSH authentication key. `DELETE /user/keys/{key_id}`
    public func deleteSSHKey(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/keys/\(id)"))
    }

    // MARK: SSH signing keys

    /// The signed-in user's SSH signing keys. `GET /user/ssh_signing_keys`
    public func sshSigningKeys(perPage: Int = 100) -> Paginated<SSHSigningKey> {
        client.paginate(GitHubRequest(.get, "/user/ssh_signing_keys", query: .query(("per_page", perPage))))
    }

    /// A user's SSH signing keys. `GET /users/{username}/ssh_signing_keys`
    public func sshSigningKeys(of login: String, perPage: Int = 100) -> Paginated<SSHSigningKey> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/ssh_signing_keys", query: .query(("per_page", perPage))))
    }

    /// One of the signed-in user's SSH signing keys. `GET /user/ssh_signing_keys/{ssh_signing_key_id}`
    public func sshSigningKey(id: Int) async throws(GitHubError) -> SSHSigningKey {
        try await client.value(GitHubRequest(.get, "/user/ssh_signing_keys/\(id)"))
    }

    /// Adds an SSH key for signing commits. `POST /user/ssh_signing_keys`
    public func addSSHSigningKey(_ key: String, title: String? = nil) async throws(GitHubError) -> SSHSigningKey {
        try await client.value(GitHubRequest(.post, "/user/ssh_signing_keys", body: NewKey(key: key, title: title)))
    }

    /// Removes an SSH signing key. `DELETE /user/ssh_signing_keys/{ssh_signing_key_id}`
    public func deleteSSHSigningKey(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/ssh_signing_keys/\(id)"))
    }

    private struct NewKey: Encodable, Sendable {
        let key: String
        let title: String?
    }

    // MARK: Social accounts

    private struct SocialBody: Encodable, Sendable { let account_urls: [URL] }

    /// The signed-in user's linked social profiles. `GET /user/social_accounts`
    public func socialAccounts(perPage: Int = 100) -> Paginated<SocialAccount> {
        client.paginate(GitHubRequest(.get, "/user/social_accounts", query: .query(("per_page", perPage))))
    }

    /// A user's linked social profiles. `GET /users/{username}/social_accounts`
    public func socialAccounts(of login: String, perPage: Int = 100) -> Paginated<SocialAccount> {
        client.paginate(GitHubRequest(.get, "/users/\(escape(login))/social_accounts", query: .query(("per_page", perPage))))
    }

    /// Links social profiles. `POST /user/social_accounts`
    @discardableResult
    public func addSocialAccounts(_ urls: [URL]) async throws(GitHubError) -> [SocialAccount] {
        try await client.value(GitHubRequest(.post, "/user/social_accounts", body: SocialBody(account_urls: urls)))
    }

    /// Unlinks social profiles. `DELETE /user/social_accounts`
    public func deleteSocialAccounts(_ urls: [URL]) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/social_accounts", body: SocialBody(account_urls: urls)))
    }
}
