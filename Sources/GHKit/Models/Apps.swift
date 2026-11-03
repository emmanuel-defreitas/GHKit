import Foundation

/// Permissions keyed by name, such as `["issues": "write", "metadata": "read"]`.
public typealias AppPermissions = [String: String]

/// A GitHub App (`integration`).
public struct GitHubApp: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var slug: String?
    public var nodeID: String
    public var clientID: String?
    public var name: String
    public var description: String?
    public var owner: SimpleUser?
    public var externalURL: URL?
    public var htmlURL: URL
    public var createdAt: Date
    public var updatedAt: Date
    public var permissions: AppPermissions
    public var events: [String]
    public var installationsCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, owner, permissions, events
        case nodeID = "node_id"
        case clientID = "client_id"
        case externalURL = "external_url"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case installationsCount = "installations_count"
    }
}

extension GitHubApp {
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        slug = try c.decodeIfPresent(String.self, forKey: .slug)
        nodeID = try c.decode(String.self, forKey: .nodeID)
        clientID = try c.decodeIfPresent(String.self, forKey: .clientID)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        // Branch protection responses send a partial owner without a `type`.
        owner = try? c.decodeIfPresent(SimpleUser.self, forKey: .owner)
        externalURL = try c.decodeIfPresent(URL.self, forKey: .externalURL)
        htmlURL = try c.decode(URL.self, forKey: .htmlURL)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        permissions = try c.decode(AppPermissions.self, forKey: .permissions)
        events = try c.decode([String].self, forKey: .events)
        installationsCount = try c.decodeIfPresent(Int.self, forKey: .installationsCount)
    }
}

/// One installation of a GitHub App on a user, organization, or enterprise.
public struct Installation: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var appID: Int
    public var appSlug: String
    public var clientID: String?
    public var account: Account?
    /// `all` or `selected`.
    public var repositorySelection: String
    public var accessTokensURL: URL
    public var repositoriesURL: URL
    public var htmlURL: URL
    public var targetID: Int
    public var targetType: String
    public var permissions: AppPermissions
    public var events: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var suspendedAt: Date?
    public var suspendedBy: SimpleUser?

    /// A user, organization, or enterprise. Enterprises have a `slug` instead of a `login`.
    public struct Account: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var nodeID: String?
        public var login: String?
        public var slug: String?
        public var name: String?
        public var type: String?
        public var avatarURL: URL?
        public var htmlURL: URL?

        public var displayName: String { login ?? slug ?? name ?? String(id) }

        enum CodingKeys: String, CodingKey {
            case id, login, slug, name, type
            case nodeID = "node_id"
            case avatarURL = "avatar_url"
            case htmlURL = "html_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, account, permissions, events
        case appID = "app_id"
        case appSlug = "app_slug"
        case clientID = "client_id"
        case repositorySelection = "repository_selection"
        case accessTokensURL = "access_tokens_url"
        case repositoriesURL = "repositories_url"
        case htmlURL = "html_url"
        case targetID = "target_id"
        case targetType = "target_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case suspendedAt = "suspended_at"
        case suspendedBy = "suspended_by"
    }
}

/// A short-lived token for acting as an installation.
public struct InstallationToken: Sendable, Hashable, Codable {
    public var token: String
    public var expiresAt: Date
    public var permissions: AppPermissions?
    public var repositorySelection: String?

    enum CodingKeys: String, CodingKey {
        case token, permissions
        case expiresAt = "expires_at"
        case repositorySelection = "repository_selection"
    }
}

/// Limits for a new installation token. Leave everything `nil` to get the
/// installation's full access.
public struct InstallationTokenOptions: Sendable, Hashable, Encodable {
    public var repositories: [String]?
    public var repositoryIDs: [Int]?
    public var permissions: AppPermissions?

    public init(repositories: [String]? = nil, repositoryIDs: [Int]? = nil, permissions: AppPermissions? = nil) {
        self.repositories = repositories
        self.repositoryIDs = repositoryIDs
        self.permissions = permissions
    }

    enum CodingKeys: String, CodingKey {
        case repositories, permissions
        case repositoryIDs = "repository_ids"
    }
}

/// An OAuth token as seen by its app, from the `/applications` token endpoints.
public struct OAuthAuthorization: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var url: URL?
    public var scopes: [String]?
    public var token: String
    public var tokenLastEight: String?
    public var hashedToken: String?
    public var app: App
    public var note: String?
    public var noteURL: URL?
    public var fingerprint: String?
    public var user: SimpleUser?
    public var createdAt: Date
    public var updatedAt: Date
    public var expiresAt: Date?

    public struct App: Sendable, Hashable, Codable {
        public var clientID: String
        public var name: String
        public var url: URL

        enum CodingKeys: String, CodingKey {
            case name, url
            case clientID = "client_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, url, scopes, token, app, note, fingerprint, user
        case tokenLastEight = "token_last_eight"
        case hashedToken = "hashed_token"
        case noteURL = "note_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}

/// Every rate limit bucket, from `GET /rate_limit`.
public struct RateLimitOverview: Sendable, Hashable, Decodable {
    /// Buckets keyed by name: `core`, `search`, `graphql`, `code_search`, and others.
    public var resources: [String: RateLimit]
    public var rate: RateLimit

    public var core: RateLimit? { resources["core"] }
    public var graphQL: RateLimit? { resources["graphql"] }
    public var search: RateLimit? { resources["search"] }
}
