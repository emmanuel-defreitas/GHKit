import Foundation

/// A user or organization as it appears inside other objects (`simple-user`).
public struct SimpleUser: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var login: String
    public var nodeID: String
    public var avatarURL: URL?
    public var htmlURL: URL?
    public var url: URL?
    /// `User`, `Organization`, or `Bot`.
    public var type: String
    public var siteAdmin: Bool?
    public var name: String?
    public var email: String?

    public var isOrganization: Bool { type == "Organization" }

    public init(
        id: Int, login: String, nodeID: String, avatarURL: URL? = nil, htmlURL: URL? = nil, url: URL? = nil,
        type: String = "User", siteAdmin: Bool? = nil, name: String? = nil, email: String? = nil
    ) {
        self.id = id
        self.login = login
        self.nodeID = nodeID
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.url = url
        self.type = type
        self.siteAdmin = siteAdmin
        self.name = name
        self.email = email
    }

    enum CodingKeys: String, CodingKey {
        case id, login, url, type, name, email
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case siteAdmin = "site_admin"
    }
}

/// A full user profile. Private fields (plan, disk usage, 2FA) are only set for the
/// authenticated user.
public struct User: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var login: String
    public var nodeID: String
    public var avatarURL: URL?
    public var htmlURL: URL?
    public var type: String
    public var siteAdmin: Bool?
    public var name: String?
    public var company: String?
    public var blog: String?
    public var location: String?
    public var email: String?
    public var hireable: Bool?
    public var bio: String?
    public var twitterUsername: String?
    public var publicRepos: Int?
    public var publicGists: Int?
    public var followers: Int?
    public var following: Int?
    public var createdAt: Date?
    public var updatedAt: Date?
    // Authenticated user only
    public var privateGists: Int?
    public var totalPrivateRepos: Int?
    public var ownedPrivateRepos: Int?
    public var diskUsage: Int?
    public var collaborators: Int?
    public var twoFactorAuthentication: Bool?
    public var plan: Plan?

    public struct Plan: Sendable, Hashable, Codable {
        public var name: String
        public var space: Int?
        public var privateRepos: Int?
        public var collaborators: Int?

        enum CodingKeys: String, CodingKey {
            case name, space, collaborators
            case privateRepos = "private_repos"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, login, type, name, company, blog, location, email, hireable, bio, followers, following, collaborators, plan
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case siteAdmin = "site_admin"
        case twitterUsername = "twitter_username"
        case publicRepos = "public_repos"
        case publicGists = "public_gists"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case privateGists = "private_gists"
        case totalPrivateRepos = "total_private_repos"
        case ownedPrivateRepos = "owned_private_repos"
        case diskUsage = "disk_usage"
        case twoFactorAuthentication = "two_factor_authentication"
    }
}

/// Who the client is signed in as, and what the token allows.
public struct AuthenticationStatus: Sendable, Hashable {
    public var user: User
    /// Scopes on an OAuth token or classic PAT. `nil` for fine-grained tokens and app tokens.
    public var scopes: [OAuthScope]?
    /// When the token expires, if GitHub reports it.
    public var tokenExpiresAt: Date?
    public var rateLimit: RateLimit?

    public func hasScope(_ scope: OAuthScope) -> Bool { scopes?.contains(scope) ?? false }
}
