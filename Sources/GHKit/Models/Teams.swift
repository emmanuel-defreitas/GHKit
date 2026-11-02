import Foundation

/// Who can see a team.
public struct TeamPrivacy: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Visible to every member of the organization. Required for nested teams.
    public static let closed: Self = "closed"
    /// Visible only to the team's members and organization owners.
    public static let secret: Self = "secret"
}

/// Whether @-mentioning a team notifies its members.
public struct TeamNotificationSetting: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let enabled: Self = "notifications_enabled"
    public static let disabled: Self = "notifications_disabled"
}

/// A member's role on a team.
public struct TeamRole: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let member: Self = "member"
    /// Can add and remove members and change the team's settings.
    public static let maintainer: Self = "maintainer"
}

/// A role a team can have on a repository: `pull`, `triage`, `push`, `maintain`, `admin`, or a custom role's name.
public struct RepositoryRole: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pull: Self = "pull"
    public static let triage: Self = "triage"
    public static let push: Self = "push"
    public static let maintain: Self = "maintain"
    public static let admin: Self = "admin"
}

/// Narrows team lists by where the team is managed.
public enum TeamTypeFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, organization, enterprise
    public var description: String { rawValue }
}

/// Narrows team member lists by role.
public enum TeamRoleFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, member, maintainer
    public var description: String { rawValue }
}

/// A team member and their role (`team-member`).
public struct TeamMember: Sendable, Hashable, Codable, Identifiable {
    public var user: SimpleUser
    public var role: TeamRole?
    /// `true` when the membership comes from a child team.
    public var inherited: Bool?

    public var id: Int { user.id }

    enum CodingKeys: String, CodingKey { case role, inherited }

    public init(from decoder: any Decoder) throws {
        user = try SimpleUser(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decodeIfPresent(TeamRole.self, forKey: .role)
        inherited = try c.decodeIfPresent(Bool.self, forKey: .inherited)
    }

    public func encode(to encoder: any Encoder) throws {
        try user.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(inherited, forKey: .inherited)
    }
}

/// Someone's membership on a team (`team-membership`).
public struct TeamMembership: Sendable, Hashable, Codable {
    public var url: URL?
    public var role: TeamRole
    /// `.pending` until the person accepts their organization invitation.
    public var state: MembershipState
}

/// A team to create.
public struct NewTeam: Sendable, Hashable, Encodable {
    public var name: String
    public var description: String?
    /// Logins of organization members to make maintainers.
    public var maintainers: [String]
    /// `owner/name` of repositories to add the team to.
    public var repositoryNames: [String]
    public var privacy: TeamPrivacy?
    public var notificationSetting: TeamNotificationSetting?
    /// Nests the new team under another.
    public var parentTeamID: Int?

    public init(
        name: String, description: String? = nil, maintainers: [String] = [], repositoryNames: [String] = [],
        privacy: TeamPrivacy? = nil, notificationSetting: TeamNotificationSetting? = nil, parentTeamID: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.maintainers = maintainers
        self.repositoryNames = repositoryNames
        self.privacy = privacy
        self.notificationSetting = notificationSetting
        self.parentTeamID = parentTeamID
    }

    enum CodingKeys: String, CodingKey {
        case name, description, maintainers, privacy
        case repositoryNames = "repo_names"
        case notificationSetting = "notification_setting"
        case parentTeamID = "parent_team_id"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        if !maintainers.isEmpty { try c.encode(maintainers, forKey: .maintainers) }
        if !repositoryNames.isEmpty { try c.encode(repositoryNames, forKey: .repositoryNames) }
        try c.encodeIfPresent(privacy, forKey: .privacy)
        try c.encodeIfPresent(notificationSetting, forKey: .notificationSetting)
        try c.encodeIfPresent(parentTeamID, forKey: .parentTeamID)
    }
}

/// Changes to a team. `nil` leaves a field as it is.
public struct TeamUpdate: Sendable, Hashable, Encodable {
    /// Where a team sits in the hierarchy.
    public enum Parent: Sendable, Hashable {
        case team(id: Int)
        /// Moves the team to the top level.
        case topLevel
    }

    /// Renaming a team changes its slug.
    public var name: String?
    public var description: String?
    public var privacy: TeamPrivacy?
    public var notificationSetting: TeamNotificationSetting?
    public var parent: Parent?

    public init(
        name: String? = nil, description: String? = nil, privacy: TeamPrivacy? = nil,
        notificationSetting: TeamNotificationSetting? = nil, parent: Parent? = nil
    ) {
        self.name = name
        self.description = description
        self.privacy = privacy
        self.notificationSetting = notificationSetting
        self.parent = parent
    }

    enum CodingKeys: String, CodingKey {
        case name, description, privacy
        case notificationSetting = "notification_setting"
        case parentTeamID = "parent_team_id"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(privacy, forKey: .privacy)
        try c.encodeIfPresent(notificationSetting, forKey: .notificationSetting)
        switch parent {
        case .team(let id)?: try c.encode(id, forKey: .parentTeamID)
        case .topLevel?: try c.encodeNil(forKey: .parentTeamID)
        case nil: break
        }
    }
}
