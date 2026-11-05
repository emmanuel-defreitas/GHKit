import Foundation

/// A full organization profile (`organization-full`).
///
/// Plan, billing, and member settings are only set for organization owners.
public struct Organization: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var login: String
    public var nodeID: String
    public var url: URL?
    public var htmlURL: URL?
    public var avatarURL: URL?
    public var description: String?
    public var name: String?
    public var company: String?
    public var blog: String?
    public var location: String?
    public var email: String?
    public var twitterUsername: String?
    public var isVerified: Bool?
    public var type: String?
    public var hasOrganizationProjects: Bool?
    public var hasRepositoryProjects: Bool?
    public var publicRepos: Int?
    public var publicGists: Int?
    public var followers: Int?
    public var following: Int?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var archivedAt: Date?

    // Owner-only
    public var totalPrivateRepos: Int?
    public var ownedPrivateRepos: Int?
    public var privateGists: Int?
    public var diskUsage: Int?
    public var collaborators: Int?
    public var billingEmail: String?
    public var plan: Plan?
    public var twoFactorRequirementEnabled: Bool?
    public var defaultRepositoryPermission: RepositoryPermission?
    public var defaultRepositoryBranch: String?
    public var membersCanCreateRepositories: Bool?
    public var membersCanCreatePublicRepositories: Bool?
    public var membersCanCreatePrivateRepositories: Bool?
    public var membersCanCreateInternalRepositories: Bool?
    public var membersCanCreatePages: Bool?
    public var membersCanCreatePublicPages: Bool?
    public var membersCanCreatePrivatePages: Bool?
    public var membersCanForkPrivateRepositories: Bool?
    public var membersCanDeleteRepositories: Bool?
    public var membersCanChangeRepoVisibility: Bool?
    public var membersCanInviteOutsideCollaborators: Bool?
    public var membersCanDeleteIssues: Bool?
    public var membersCanCreateTeams: Bool?
    public var membersCanViewDependencyInsights: Bool?
    public var readersCanCreateDiscussions: Bool?
    public var displayCommenterFullNameSettingEnabled: Bool?
    public var webCommitSignoffRequired: Bool?
    public var deployKeysEnabledForRepositories: Bool?

    /// The organization's billing plan.
    public struct Plan: Sendable, Hashable, Codable {
        public var name: String
        public var space: Int?
        public var privateRepos: Int?
        public var seats: Int?
        public var filledSeats: Int?

        enum CodingKeys: String, CodingKey {
            case name, space, seats
            case privateRepos = "private_repos"
            case filledSeats = "filled_seats"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, login, url, description, name, company, blog, location, email, type, followers, following
        case collaborators, plan
        case nodeID = "node_id"
        case htmlURL = "html_url"
        case avatarURL = "avatar_url"
        case twitterUsername = "twitter_username"
        case isVerified = "is_verified"
        case hasOrganizationProjects = "has_organization_projects"
        case hasRepositoryProjects = "has_repository_projects"
        case publicRepos = "public_repos"
        case publicGists = "public_gists"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
        case totalPrivateRepos = "total_private_repos"
        case ownedPrivateRepos = "owned_private_repos"
        case privateGists = "private_gists"
        case diskUsage = "disk_usage"
        case billingEmail = "billing_email"
        case twoFactorRequirementEnabled = "two_factor_requirement_enabled"
        case defaultRepositoryPermission = "default_repository_permission"
        case defaultRepositoryBranch = "default_repository_branch"
        case membersCanCreateRepositories = "members_can_create_repositories"
        case membersCanCreatePublicRepositories = "members_can_create_public_repositories"
        case membersCanCreatePrivateRepositories = "members_can_create_private_repositories"
        case membersCanCreateInternalRepositories = "members_can_create_internal_repositories"
        case membersCanCreatePages = "members_can_create_pages"
        case membersCanCreatePublicPages = "members_can_create_public_pages"
        case membersCanCreatePrivatePages = "members_can_create_private_pages"
        case membersCanForkPrivateRepositories = "members_can_fork_private_repositories"
        case membersCanDeleteRepositories = "members_can_delete_repositories"
        case membersCanChangeRepoVisibility = "members_can_change_repo_visibility"
        case membersCanInviteOutsideCollaborators = "members_can_invite_outside_collaborators"
        case membersCanDeleteIssues = "members_can_delete_issues"
        case membersCanCreateTeams = "members_can_create_teams"
        case membersCanViewDependencyInsights = "members_can_view_dependency_insights"
        case readersCanCreateDiscussions = "readers_can_create_discussions"
        case displayCommenterFullNameSettingEnabled = "display_commenter_full_name_setting_enabled"
        case webCommitSignoffRequired = "web_commit_signoff_required"
        case deployKeysEnabledForRepositories = "deploy_keys_enabled_for_repositories"
    }
}

/// The base permission members get on an organization's repositories.
public struct RepositoryPermission: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let none: Self = "none"
    public static let read: Self = "read"
    public static let write: Self = "write"
    public static let admin: Self = "admin"
}

// MARK: Teams

/// A team in an organization (`team`, `team-full`).
///
/// Counts, dates, and the organization are only set when you fetch one team or your own teams.
public struct Team: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var slug: String
    public var description: String?
    /// `secret` or `closed`.
    public var privacy: String?
    /// `notifications_enabled` or `notifications_disabled`.
    public var notificationSetting: String?
    public var permission: String?
    public var url: URL?
    public var htmlURL: URL?
    public var membersURL: String?
    public var repositoriesURL: URL?
    /// `organization` or `enterprise`.
    public var type: String?
    public var organizationID: Int?
    public var enterpriseID: Int?
    public var parent: Parent?
    public var membersCount: Int?
    public var reposCount: Int?
    public var organization: Organization?
    /// The LDAP group the team syncs with, on GitHub Enterprise Server.
    public var ldapDN: String?
    public var createdAt: Date?
    public var updatedAt: Date?

    /// The team a team is nested under.
    public struct Parent: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var nodeID: String
        public var name: String
        public var slug: String
        public var description: String?
        public var privacy: String?
        public var permission: String?
        public var url: URL?
        public var htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case id, name, slug, description, privacy, permission, url
            case nodeID = "node_id"
            case htmlURL = "html_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, privacy, permission, url, type, parent
        case nodeID = "node_id"
        case notificationSetting = "notification_setting"
        case htmlURL = "html_url"
        case membersURL = "members_url"
        case repositoriesURL = "repositories_url"
        case organizationID = "organization_id"
        case enterpriseID = "enterprise_id"
        case membersCount = "members_count"
        case reposCount = "repos_count"
        case organization
        case ldapDN = "ldap_dn"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
