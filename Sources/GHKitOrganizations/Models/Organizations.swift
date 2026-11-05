import Foundation
import GHKitCore

/// An organization as it appears in lists and inside other objects (`organization-simple`).
public struct SimpleOrganization: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var login: String
    public var nodeID: String
    public var url: URL?
    public var avatarURL: URL?
    public var description: String?

    enum CodingKeys: String, CodingKey {
        case id, login, url, description
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
    }
}

/// Changes to an organization's profile and settings. `nil` leaves a field as it is.
///
/// Security defaults for new repositories (Dependabot, secret scanning, and others) are
/// set through code security configurations, not here.
public struct OrganizationUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var description: String?
    public var company: String?
    public var blog: String?
    public var location: String?
    public var email: String?
    public var twitterUsername: String?
    public var billingEmail: String?
    public var hasOrganizationProjects: Bool?
    public var hasRepositoryProjects: Bool?
    public var defaultRepositoryPermission: RepositoryPermission?
    public var membersCanCreateRepositories: Bool?
    public var membersCanCreatePublicRepositories: Bool?
    public var membersCanCreatePrivateRepositories: Bool?
    public var membersCanCreateInternalRepositories: Bool?
    public var membersCanCreatePages: Bool?
    public var membersCanCreatePublicPages: Bool?
    public var membersCanCreatePrivatePages: Bool?
    public var membersCanForkPrivateRepositories: Bool?
    public var webCommitSignoffRequired: Bool?
    public var deployKeysEnabledForRepositories: Bool?

    public init(
        name: String? = nil, description: String? = nil, company: String? = nil, blog: String? = nil,
        location: String? = nil, email: String? = nil, twitterUsername: String? = nil, billingEmail: String? = nil,
        hasOrganizationProjects: Bool? = nil, hasRepositoryProjects: Bool? = nil,
        defaultRepositoryPermission: RepositoryPermission? = nil,
        membersCanCreateRepositories: Bool? = nil, membersCanCreatePublicRepositories: Bool? = nil,
        membersCanCreatePrivateRepositories: Bool? = nil, membersCanCreateInternalRepositories: Bool? = nil,
        membersCanCreatePages: Bool? = nil, membersCanCreatePublicPages: Bool? = nil,
        membersCanCreatePrivatePages: Bool? = nil, membersCanForkPrivateRepositories: Bool? = nil,
        webCommitSignoffRequired: Bool? = nil, deployKeysEnabledForRepositories: Bool? = nil
    ) {
        self.name = name
        self.description = description
        self.company = company
        self.blog = blog
        self.location = location
        self.email = email
        self.twitterUsername = twitterUsername
        self.billingEmail = billingEmail
        self.hasOrganizationProjects = hasOrganizationProjects
        self.hasRepositoryProjects = hasRepositoryProjects
        self.defaultRepositoryPermission = defaultRepositoryPermission
        self.membersCanCreateRepositories = membersCanCreateRepositories
        self.membersCanCreatePublicRepositories = membersCanCreatePublicRepositories
        self.membersCanCreatePrivateRepositories = membersCanCreatePrivateRepositories
        self.membersCanCreateInternalRepositories = membersCanCreateInternalRepositories
        self.membersCanCreatePages = membersCanCreatePages
        self.membersCanCreatePublicPages = membersCanCreatePublicPages
        self.membersCanCreatePrivatePages = membersCanCreatePrivatePages
        self.membersCanForkPrivateRepositories = membersCanForkPrivateRepositories
        self.webCommitSignoffRequired = webCommitSignoffRequired
        self.deployKeysEnabledForRepositories = deployKeysEnabledForRepositories
    }

    enum CodingKeys: String, CodingKey {
        case name, description, company, blog, location, email
        case twitterUsername = "twitter_username"
        case billingEmail = "billing_email"
        case hasOrganizationProjects = "has_organization_projects"
        case hasRepositoryProjects = "has_repository_projects"
        case defaultRepositoryPermission = "default_repository_permission"
        case membersCanCreateRepositories = "members_can_create_repositories"
        case membersCanCreatePublicRepositories = "members_can_create_public_repositories"
        case membersCanCreatePrivateRepositories = "members_can_create_private_repositories"
        case membersCanCreateInternalRepositories = "members_can_create_internal_repositories"
        case membersCanCreatePages = "members_can_create_pages"
        case membersCanCreatePublicPages = "members_can_create_public_pages"
        case membersCanCreatePrivatePages = "members_can_create_private_pages"
        case membersCanForkPrivateRepositories = "members_can_fork_private_repositories"
        case webCommitSignoffRequired = "web_commit_signoff_required"
        case deployKeysEnabledForRepositories = "deploy_keys_enabled_for_repositories"
    }
}

// MARK: Membership

/// Someone's membership in an organization (`org-membership`).
public struct OrganizationMembership: Sendable, Hashable, Codable {
    public var url: URL?
    public var state: MembershipState
    public var role: OrganizationRole
    /// `false` when the membership comes only from enterprise teams.
    public var directMembership: Bool?
    public var enterpriseTeamsProvidingIndirectMembership: [String]?
    public var organizationURL: URL?
    public var organization: SimpleOrganization
    public var user: SimpleUser?
    public var permissions: Permissions?

    public struct Permissions: Sendable, Hashable, Codable {
        public var canCreateRepository: Bool

        enum CodingKeys: String, CodingKey {
            case canCreateRepository = "can_create_repository"
        }
    }

    enum CodingKeys: String, CodingKey {
        case url, state, role, organization, user, permissions
        case directMembership = "direct_membership"
        case enterpriseTeamsProvidingIndirectMembership = "enterprise_teams_providing_indirect_membership"
        case organizationURL = "organization_url"
    }
}

/// Whether a membership is active or still waiting for the invitee.
public struct MembershipState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let active: Self = "active"
    public static let pending: Self = "pending"
}

/// A member's role in an organization.
public struct OrganizationRole: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let admin: Self = "admin"
    public static let member: Self = "member"
    public static let billingManager: Self = "billing_manager"
}

/// Narrows member lists by two-factor authentication status.
public enum MemberFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all
    /// Members without two-factor authentication.
    case twoFactorDisabled = "2fa_disabled"
    /// Members using only insecure two-factor methods, such as SMS.
    case twoFactorInsecure = "2fa_insecure"

    public var description: String { rawValue }
}

/// Narrows member lists by role.
public enum MemberRoleFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, admin, member
    public var description: String { rawValue }
}

// MARK: Invitations

/// A pending or failed invitation to join an organization (`organization-invitation`).
public struct OrganizationInvitation: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var login: String?
    public var email: String?
    public var role: InvitationRole
    public var createdAt: Date?
    public var failedAt: Date?
    public var failedReason: String?
    public var inviter: SimpleUser?
    public var teamCount: Int?
    public var invitationTeamsURL: URL?
    /// `member` or `scim`.
    public var invitationSource: String?

    enum CodingKeys: String, CodingKey {
        case id, login, email, role, inviter
        case nodeID = "node_id"
        case createdAt = "created_at"
        case failedAt = "failed_at"
        case failedReason = "failed_reason"
        case teamCount = "team_count"
        case invitationTeamsURL = "invitation_teams_url"
        case invitationSource = "invitation_source"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nodeID = try c.decode(String.self, forKey: .nodeID)
        login = try c.decodeIfPresent(String.self, forKey: .login)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        role = try c.decode(InvitationRole.self, forKey: .role)
        // GitHub sends "" rather than null for invitations that haven't failed.
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt).flatMap(GitHubJSON.parseDate)
        failedAt = try c.decodeIfPresent(String.self, forKey: .failedAt).flatMap(GitHubJSON.parseDate)
        failedReason = try c.decodeIfPresent(String.self, forKey: .failedReason).flatMap { $0.isEmpty ? nil : $0 }
        inviter = try c.decodeIfPresent(SimpleUser.self, forKey: .inviter)
        teamCount = try c.decodeIfPresent(Int.self, forKey: .teamCount)
        invitationTeamsURL = try c.decodeIfPresent(URL.self, forKey: .invitationTeamsURL)
        invitationSource = try c.decodeIfPresent(String.self, forKey: .invitationSource)
    }
}

/// The role an invitee gets on joining.
public struct InvitationRole: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let admin: Self = "admin"
    public static let directMember: Self = "direct_member"
    public static let billingManager: Self = "billing_manager"
    public static let hiringManager: Self = "hiring_manager"
    /// Restores a former member's previous role and access, if it's within the last three months.
    public static let reinstate: Self = "reinstate"
}

/// An invitation to send.
public struct NewOrganizationInvitation: Sendable, Hashable, Encodable {
    /// Who to invite.
    public enum Invitee: Sendable, Hashable {
        case user(id: Int)
        case email(String)
    }

    public var invitee: Invitee
    public var role: InvitationRole
    public var teamIDs: [Int]

    public init(_ invitee: Invitee, role: InvitationRole = .directMember, teamIDs: [Int] = []) {
        self.invitee = invitee
        self.role = role
        self.teamIDs = teamIDs
    }

    enum CodingKeys: String, CodingKey {
        case role
        case inviteeID = "invitee_id"
        case email
        case teamIDs = "team_ids"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch invitee {
        case .user(let id): try c.encode(id, forKey: .inviteeID)
        case .email(let email): try c.encode(email, forKey: .email)
        }
        try c.encode(role, forKey: .role)
        if !teamIDs.isEmpty { try c.encode(teamIDs, forKey: .teamIDs) }
    }
}

/// Narrows pending invitations by the role offered.
public enum InvitationRoleFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, admin
    case directMember = "direct_member"
    case billingManager = "billing_manager"
    case hiringManager = "hiring_manager"
    public var description: String { rawValue }
}

/// Narrows pending invitations by where they came from.
public enum InvitationSourceFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, member, scim
    public var description: String { rawValue }
}
