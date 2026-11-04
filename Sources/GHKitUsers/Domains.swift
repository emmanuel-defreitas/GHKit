import GHKitCore

extension GitHubDomain {
    /// User profiles, emails, keys, and followers.
    public static let users = GitHubDomain(
        "users",
        read: GitHubAccess(
            scopes: [.readUser, .userEmail],
            permissions: [.init("email_addresses", .read), .init("followers", .read), .init("git_ssh_keys", .read), .init("gpg_keys", .read)]),
        write: GitHubAccess(
            scopes: [.user, .adminPublicKey, .adminGPGKey],
            permissions: [
                .init("profile", .write), .init("email_addresses", .write), .init("followers", .write), .init("git_ssh_keys", .write),
                .init("gpg_keys", .write),
            ])
    )
}
