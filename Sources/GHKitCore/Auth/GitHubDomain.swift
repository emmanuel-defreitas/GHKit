import Foundation

/// A part of the GitHub API, such as issues or projects, and the access its endpoints need.
///
/// Each domain module declares the domains it covers, such as `.issues` in GHKitIssues, and tags the
/// requests it sends with them. A ``RoutedAuthenticator`` uses the tag to pick a credential, and
/// ``GitHubAccess`` turns a list of domains into the scopes or permissions to ask for:
///
///     let access = [GitHubDomain.issues, .pullRequests].access(.write)
///     print(access.scopes)        // [repo]
///     print(access.permissions)   // issues=write, metadata=read, pull_requests=write, contents=write
public struct GitHubDomain: Sendable, Hashable, CustomStringConvertible {
    /// How much an app does with a domain.
    public enum Level: Sendable, Hashable {
        /// Reading only.
        case read
        /// Reading, creating, changing, and deleting.
        case write
    }

    /// A stable name, such as `issues` or `pull_requests`.
    public let name: String
    /// What reading needs.
    public let readAccess: GitHubAccess
    /// What reading and writing need.
    public let writeAccess: GitHubAccess

    /// - Parameters:
    ///   - name: A stable name. Two domains with the same name are equal.
    ///   - read: What the domain's read endpoints need.
    ///   - write: What its write endpoints need on top of `read`.
    public init(_ name: String, read: GitHubAccess = GitHubAccess(), write: GitHubAccess = GitHubAccess()) {
        self.name = name
        self.readAccess = read
        self.writeAccess = read.union(write)
    }

    /// What `level` needs.
    public func access(_ level: Level) -> GitHubAccess {
        switch level {
        case .read: readAccess
        case .write: writeAccess
        }
    }

    public var description: String { name }

    public static func == (lhs: GitHubDomain, rhs: GitHubDomain) -> Bool { lhs.name == rhs.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
}

extension Sequence where Element == GitHubDomain {
    /// What a credential needs to use all of these domains at `level`.
    public func access(_ level: GitHubDomain.Level) -> GitHubAccess {
        reduce(GitHubAccess()) { $0.union($1.access(level)) }
    }
}

/// One permission of a fine-grained personal access token or GitHub App, such as `issues=write`.
public struct GitHubPermission: Sendable, Hashable, Comparable, CustomStringConvertible {
    public enum Level: String, Sendable, Hashable, Comparable {
        case read, write, admin

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rank < rhs.rank }

        private var rank: Int {
            switch self {
            case .read: 0
            case .write: 1
            case .admin: 2
            }
        }
    }

    /// GitHub's name for the permission, such as `contents` or `organization_projects`.
    public var name: String
    public var level: Level

    public init(_ name: String, _ level: Level) {
        self.name = name
        self.level = level
    }

    /// Reads `name=level`, the form GitHub uses in headers and token links.
    public init?(_ text: some StringProtocol) {
        let parts = text.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, let level = Level(rawValue: parts[1]) else { return nil }
        self.init(parts[0], level)
    }

    public var description: String { "\(name)=\(level.rawValue)" }

    public static func < (lhs: GitHubPermission, rhs: GitHubPermission) -> Bool {
        (lhs.name, lhs.level) < (rhs.name, rhs.level)
    }

    /// Reads an `X-Accepted-GitHub-Permissions` value: sets separated by `;`, any one of which is enough.
    static func parseAlternatives(_ header: String) -> [[GitHubPermission]] {
        header.split(separator: ";").map { set in set.split(separator: ",").compactMap { GitHubPermission($0) } }
            .filter { !$0.isEmpty }
    }
}

/// What a credential must allow: scopes for classic tokens and OAuth apps, and permissions for
/// fine-grained tokens and GitHub Apps.
///
/// Get one from the domains an app uses, then ask for it at sign-in or link to a token page that
/// asks for it:
///
///     let access = [GitHubDomain.repositories, .issues].access(.write)
///     let session = GitHubSession(clientID: "Iv1.abc", scopes: access.scopeList)
///     let link = access.fineGrainedTokenURL(name: "My App", owner: "acme")
///
/// The declarations cover each domain's usual endpoints. A few, such as deleting a repository or
/// managing workflow files, need more. GitHub names what's missing when a call fails; see
/// ``GitHubError/missingAccess``.
public struct GitHubAccess: Sendable, Hashable {
    /// Scopes a classic personal access token or OAuth app token needs, without any that another
    /// one in the set already grants.
    public var scopes: Set<OAuthScope>
    /// Permissions a fine-grained personal access token or GitHub App needs, by name.
    public var permissionLevels: [String: GitHubPermission.Level]

    public init(scopes: Set<OAuthScope> = [], permissions: [GitHubPermission] = []) {
        self.scopes = Self.minimized(scopes)
        self.permissionLevels = Dictionary(permissions.map { ($0.name, $0.level) }, uniquingKeysWith: max)
    }

    /// The permissions, sorted by name.
    public var permissions: [GitHubPermission] {
        permissionLevels.map { GitHubPermission($0.key, $0.value) }.sorted()
    }

    /// The scopes, sorted, for APIs that take a list such as ``DeviceFlow``.
    public var scopeList: [OAuthScope] { scopes.sorted { $0.rawValue < $1.rawValue } }

    /// Everything either one needs, keeping the higher level of each permission.
    public func union(_ other: GitHubAccess) -> GitHubAccess {
        var result = self
        result.scopes = Self.minimized(scopes.union(other.scopes))
        result.permissionLevels.merge(other.permissionLevels, uniquingKeysWith: max)
        return result
    }

    /// The scopes a token with `granted` scopes still lacks. Broader scopes count for the ones they
    /// include, so `admin:org` covers `read:org`.
    public func missingScopes(granted: some Sequence<OAuthScope>) -> Set<OAuthScope> {
        let covered = Set(granted.flatMap { [$0] + ($0.includedScopes) })
        return scopes.subtracting(covered)
    }

    /// Drops scopes that another scope in the set already grants, such as `read:org` next to `admin:org`.
    static func minimized(_ scopes: Set<OAuthScope>) -> Set<OAuthScope> {
        scopes.filter { scope in !scopes.contains { $0.includedScopes.contains(scope) } }
    }

    /// A page on GitHub that creates a classic personal access token with these scopes.
    public func classicTokenURL(description: String, server: GitHubServer = .dotCom) -> URL {
        tokenURL(
            server: server, path: "settings/tokens/new",
            [("scopes", scopeList.map(\.rawValue).joined(separator: ",")), ("description", description)])
    }

    /// A page on GitHub that creates a fine-grained personal access token with these permissions.
    ///
    /// GitHub fills in the form and the person reviews it before creating the token.
    /// - Parameters:
    ///   - name: The token's name, up to 40 characters.
    ///   - description: Shown with the token in the person's settings.
    ///   - owner: The user or organization login the token can reach. A fine-grained token reaches
    ///     one account, so make one token per account and route them with ``RoutedAuthenticator``.
    public func fineGrainedTokenURL(
        name: String, description: String? = nil, owner: String? = nil, server: GitHubServer = .dotCom
    ) -> URL {
        var items: [(String, String?)] = [("name", name), ("description", description), ("target_name", owner)]
        items += permissions.map { ($0.name, $0.level.rawValue) }
        return tokenURL(server: server, path: "settings/personal-access-tokens/new", items)
    }

    private func tokenURL(server: GitHubServer, path: String, _ items: [(String, String?)]) -> URL {
        var components = URLComponents(url: server.webURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = items.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
        return components?.url ?? server.webURL
    }
}

extension OAuthScope {
    /// Scopes this one grants too, such as `read:org` for `admin:org`.
    var includedScopes: [OAuthScope] {
        switch self {
        case .repo: [.repoStatus, .repoDeployment, .publicRepo, .repoInvite, .securityEvents]
        case .adminRepoHook: [.writeRepoHook, .readRepoHook]
        case .writeRepoHook: [.readRepoHook]
        case .adminOrg: [.writeOrg, .readOrg]
        case .writeOrg: [.readOrg]
        case .project: [.readProject]
        case .user: [.readUser, .userEmail, .userFollow]
        case .writePackages: [.readPackages]
        case .adminPublicKey: ["write:public_key", "read:public_key"]
        case "write:public_key": ["read:public_key"]
        case .adminGPGKey: ["write:gpg_key", "read:gpg_key"]
        case "write:gpg_key": ["read:gpg_key"]
        default: []
        }
    }
}

// MARK: - Checking credentials

/// What a credential lacked for a call, from the headers GitHub sends with a `403` or `404`.
public struct MissingAccess: Sendable, Hashable, CustomStringConvertible {
    /// Permission sets that would have worked. Any one set is enough.
    public var acceptedPermissions: [[GitHubPermission]]
    /// Scopes that would have worked, for classic and OAuth tokens. Any one is enough.
    public var acceptedScopes: [OAuthScope]
    /// The scopes the token has, for classic and OAuth tokens.
    public var grantedScopes: [OAuthScope]?

    public var description: String {
        var parts: [String] = []
        if !acceptedPermissions.isEmpty {
            let sets = acceptedPermissions.map { $0.map(\.description).joined(separator: ", ") }
            parts.append("needs permissions " + sets.joined(separator: " or "))
        }
        if !acceptedScopes.isEmpty {
            parts.append("needs one of the scopes " + acceptedScopes.map(\.rawValue).joined(separator: ", "))
        }
        if let grantedScopes {
            parts.append("token has " + (grantedScopes.isEmpty ? "no scopes" : grantedScopes.map(\.rawValue).joined(separator: ", ")))
        }
        return parts.joined(separator: "; ")
    }
}

extension ResponseMetadata {
    /// Fine-grained permission sets the endpoint accepts, any one of which is enough.
    /// GitHub sends them to fine-grained tokens and GitHub Apps.
    public var acceptedPermissions: [[GitHubPermission]]? {
        self[header: "x-accepted-github-permissions"].map(GitHubPermission.parseAlternatives)
    }
}

extension GitHubError {
    /// What the credential lacked, when this is a `403` or `404` and GitHub said which scopes or
    /// permissions the endpoint accepts.
    ///
    /// GitHub answers `404` rather than `403` when a credential can't see a private resource, so a `404`
    /// with this set may also mean the resource doesn't exist.
    ///
    ///     catch let error where error.missingAccess != nil {
    ///         print("GitHub says this \(error.missingAccess!)")   // "needs permissions issues=write"
    ///     }
    public var missingAccess: MissingAccess? {
        switch self {
        case .forbidden(_, let metadata), .notFound(_, let metadata):
            let permissions = metadata.acceptedPermissions ?? []
            let scopes = metadata.acceptedOAuthScopes ?? []
            guard !permissions.isEmpty || !scopes.isEmpty else { return nil }
            // A token with every accepted scope failed for another reason, such as a missing resource.
            if permissions.isEmpty, let granted = metadata.oauthScopes,
                GitHubAccess(scopes: Set(scopes)).missingScopes(granted: granted).count < scopes.count
            {
                return nil
            }
            return MissingAccess(acceptedPermissions: permissions, acceptedScopes: scopes, grantedScopes: metadata.oauthScopes)
        default:
            return nil
        }
    }
}

extension GitHubClient {
    /// The scopes the credential for `domain` lacks, or `nil` when it has no scopes to check.
    ///
    /// Classic personal access tokens and OAuth app tokens list their scopes, so this can tell ahead of
    /// time. Fine-grained tokens and GitHub Apps don't say which permissions they have; for those it
    /// returns `nil`, and a call that needs more fails with ``GitHubError/missingAccess`` set.
    ///
    ///     if let missing = try await github.missingScopes(for: .projects, .write), !missing.isEmpty {
    ///         // ask the person to sign in again with more scopes
    ///     }
    /// - Parameter owner: The account the credential will act on, for a ``RoutedAuthenticator``.
    public func missingScopes(
        for domain: GitHubDomain, _ level: GitHubDomain.Level = .read, owner: String? = nil
    ) async throws(GitHubError) -> Set<OAuthScope>? {
        // `/rate_limit` doesn't count against the rate limit, and the response lists the token's scopes.
        let response = try await scoped(to: domain, owner: owner).send(GitHubRequest<RateLimitOverview>(.get, "/rate_limit"))
        // An empty list can come from a token without scopes or from one that doesn't use them.
        guard let granted = response.metadata.oauthScopes, !granted.isEmpty else { return nil }
        return domain.access(level).missingScopes(granted: granted)
    }
}
