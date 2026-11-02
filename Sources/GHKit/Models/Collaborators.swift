import Foundation

/// Someone with access to a repository, and what they can do (`collaborator`).
public struct Collaborator: Sendable, Hashable, Codable, Identifiable {
    public var user: SimpleUser
    public var permissions: RepositoryPermissions?
    /// Such as `admin`, `write`, `read`, or a custom role.
    public var roleName: String?

    public var id: Int { user.id }

    enum CodingKeys: String, CodingKey {
        case permissions
        case roleName = "role_name"
    }

    public init(from decoder: any Decoder) throws {
        user = try SimpleUser(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        permissions = try c.decodeIfPresent(RepositoryPermissions.self, forKey: .permissions)
        roleName = try c.decodeIfPresent(String.self, forKey: .roleName)
    }

    public func encode(to encoder: any Encoder) throws {
        try user.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(permissions, forKey: .permissions)
        try c.encodeIfPresent(roleName, forKey: .roleName)
    }
}

/// Narrows collaborators by how they got access.
public enum CollaboratorAffiliation: String, Sendable, Hashable, CustomStringConvertible {
    /// Everyone with access, including organization members and teams.
    case all
    /// Only people added to the repository directly.
    case direct
    /// Only people outside the organization.
    case outside
    public var description: String { rawValue }
}

/// Someone's effective access to a repository (`repository-collaborator-permission`).
public struct CollaboratorPermission: Sendable, Hashable, Codable {
    /// `admin`, `write`, `read`, or `none`. Custom roles map to their base level.
    public var permission: String
    /// The actual role, which can be `maintain`, `triage`, or a custom role.
    public var roleName: String?
    public var user: Collaborator?

    enum CodingKeys: String, CodingKey {
        case permission, user
        case roleName = "role_name"
    }
}

/// An invitation to collaborate on a repository (`repository-invitation`).
public struct RepositoryInvitation: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    public var repository: Repository
    public var invitee: SimpleUser?
    public var inviter: SimpleUser?
    public var permissions: RepositoryInvitationPermission
    public var createdAt: Date?
    /// Invitations expire after seven days.
    public var expired: Bool?
    public var url: URL?
    public var htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, repository, invitee, inviter, permissions, expired, url
        case nodeID = "node_id"
        case createdAt = "created_at"
        case htmlURL = "html_url"
    }
}

/// The access a repository invitation grants.
public struct RepositoryInvitationPermission: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let read: Self = "read"
    public static let triage: Self = "triage"
    public static let write: Self = "write"
    public static let maintain: Self = "maintain"
    public static let admin: Self = "admin"
}

/// An SSH key that grants access to one repository (`deploy-key`).
public struct DeployKey: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var key: String
    public var title: String?
    public var verified: Bool?
    public var readOnly: Bool?
    /// `false` when an organization policy has turned deploy keys off.
    public var enabled: Bool?
    /// The login of whoever added the key.
    public var addedBy: String?
    public var createdAt: Date?
    public var lastUsed: Date?
    public var url: URL?

    enum CodingKeys: String, CodingKey {
        case id, key, title, verified, enabled, url
        case readOnly = "read_only"
        case addedBy = "added_by"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }
}

/// Turns references like `JIRA-123` into links (`autolink`).
public struct Autolink: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// Such as `JIRA-`.
    public var keyPrefix: String
    /// Contains `<num>`, such as `https://jira.example.com/browse/JIRA-<num>`.
    public var urlTemplate: String
    /// Whether the reference can contain letters, not just digits.
    public var isAlphanumeric: Bool
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case keyPrefix = "key_prefix"
        case urlTemplate = "url_template"
        case isAlphanumeric = "is_alphanumeric"
        case updatedAt = "updated_at"
    }
}
