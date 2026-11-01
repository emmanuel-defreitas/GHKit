import Foundation

// MARK: Webhooks

/// An organization webhook (`org-hook`).
public struct OrganizationWebhook: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// Always `web`.
    public var name: String
    public var events: [String]
    public var active: Bool
    public var config: WebhookConfiguration
    public var url: URL?
    public var pingURL: URL?
    public var deliveriesURL: URL?
    public var type: String?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, events, active, config, url, type
        case pingURL = "ping_url"
        case deliveriesURL = "deliveries_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Where and how a webhook delivers payloads (`webhook-config`). `nil` fields are left as they are.
public struct WebhookConfiguration: Sendable, Hashable, Codable {
    public var url: URL?
    public var contentType: WebhookContentType?
    /// Signs deliveries with `X-Hub-Signature-256`. GitHub returns it masked as `********`.
    public var secret: String?
    /// Skips TLS certificate checks. Avoid this; it allows man-in-the-middle attacks.
    public var insecureSSL: Bool?

    public init(url: URL? = nil, contentType: WebhookContentType? = nil, secret: String? = nil, insecureSSL: Bool? = nil) {
        self.url = url
        self.contentType = contentType
        self.secret = secret
        self.insecureSSL = insecureSSL
    }

    enum CodingKeys: String, CodingKey {
        case url, secret
        case contentType = "content_type"
        case insecureSSL = "insecure_ssl"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        contentType = try c.decodeIfPresent(WebhookContentType.self, forKey: .contentType)
        secret = try c.decodeIfPresent(String.self, forKey: .secret)
        // GitHub sends "0"/"1" as a string or a number.
        if let flag = try? c.decodeIfPresent(String.self, forKey: .insecureSSL) {
            insecureSSL = flag == "1"
        } else if let flag = try? c.decodeIfPresent(Int.self, forKey: .insecureSSL) {
            insecureSSL = flag == 1
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(contentType, forKey: .contentType)
        try c.encodeIfPresent(secret, forKey: .secret)
        try c.encodeIfPresent(insecureSSL.map { $0 ? "1" : "0" }, forKey: .insecureSSL)
    }
}

/// How webhook payloads are serialized.
public struct WebhookContentType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let json: Self = "json"
    /// `application/x-www-form-urlencoded`, GitHub's default.
    public static let form: Self = "form"
}

/// A webhook to create.
public struct NewWebhook: Sendable, Hashable, Encodable {
    public var config: WebhookConfiguration
    /// Event names, such as `push` or `pull_request`. `["*"]` subscribes to everything.
    public var events: [String]
    public var active: Bool

    public init(config: WebhookConfiguration, events: [String] = ["push"], active: Bool = true) {
        self.config = config
        self.events = events
        self.active = active
    }

    enum CodingKeys: String, CodingKey { case name, config, events, active }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("web", forKey: .name)
        try c.encode(config, forKey: .config)
        try c.encode(events, forKey: .events)
        try c.encode(active, forKey: .active)
    }
}

/// Changes to a webhook. `nil` leaves a field as it is.
public struct WebhookUpdate: Sendable, Hashable, Encodable {
    public var config: WebhookConfiguration?
    public var events: [String]?
    public var active: Bool?

    public init(config: WebhookConfiguration? = nil, events: [String]? = nil, active: Bool? = nil) {
        self.config = config
        self.events = events
        self.active = active
    }
}

/// One attempt to deliver a webhook payload (`hook-delivery-item`).
public struct WebhookDelivery: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// Shared by a delivery and its redeliveries.
    public var guid: String
    public var deliveredAt: Date?
    public var redelivery: Bool
    /// Seconds.
    public var duration: Double?
    /// Such as `OK` or `failed to connect`.
    public var status: String
    public var statusCode: Int
    public var event: String
    public var action: String?
    public var installationID: Int?
    public var repositoryID: Int?
    public var throttledAt: Date?

    public var succeeded: Bool { (200..<300).contains(statusCode) }

    enum CodingKeys: String, CodingKey {
        case id, guid, redelivery, duration, status, event, action
        case deliveredAt = "delivered_at"
        case statusCode = "status_code"
        case installationID = "installation_id"
        case repositoryID = "repository_id"
        case throttledAt = "throttled_at"
    }
}

/// A delivery with the full request and response (`hook-delivery`).
public struct WebhookDeliveryDetail: Sendable, Hashable, Codable, Identifiable {
    public var delivery: WebhookDelivery
    public var url: URL?
    public var request: Request
    public var response: Response

    public var id: Int { delivery.id }

    public struct Request: Sendable, Hashable, Codable {
        public var headers: [String: String]?
        public var payload: JSONValue?
    }

    public struct Response: Sendable, Hashable, Codable {
        public var headers: [String: String]?
        public var payload: String?
    }

    enum CodingKeys: String, CodingKey { case url, request, response }

    public init(from decoder: any Decoder) throws {
        delivery = try WebhookDelivery(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        request = try c.decode(Request.self, forKey: .request)
        response = try c.decode(Response.self, forKey: .response)
    }

    public func encode(to encoder: any Encoder) throws {
        try delivery.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(request, forKey: .request)
        try c.encode(response, forKey: .response)
    }
}

/// Narrows webhook deliveries by outcome.
public enum WebhookDeliveryStatus: String, Sendable, Hashable, CustomStringConvertible {
    case success, failure
    public var description: String { rawValue }
}

// MARK: Organization roles

/// A fine-grained organization role, predefined or custom (`organization-role`).
///
/// Not to be confused with ``OrganizationRole``, the admin/member role of a membership.
public struct OrganizationRoleDefinition: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var name: String
    public var description: String?
    /// The repository role every assignee also gets: `read`, `triage`, `write`, `maintain`, or `admin`.
    public var baseRole: String?
    /// `Organization`, `Enterprise`, or `Predefined`.
    public var source: String?
    public var permissions: [String]
    /// GitHub's schema calls this a user, but it's the organization the role belongs to.
    public var organization: SimpleOrganization?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, source, permissions, organization
        case baseRole = "base_role"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// How someone holds a role.
public struct RoleAssignment: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let direct: Self = "direct"
    /// Through a team.
    public static let indirect: Self = "indirect"
    /// Both directly and through a team.
    public static let mixed: Self = "mixed"
}

/// A team that holds an organization role (`team-role-assignment`).
public struct TeamRoleAssignment: Sendable, Hashable, Codable, Identifiable {
    public var team: Team
    public var assignment: RoleAssignment?

    public var id: Int { team.id }

    enum CodingKeys: String, CodingKey { case assignment }

    public init(from decoder: any Decoder) throws {
        team = try Team(from: decoder)
        assignment = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(RoleAssignment.self, forKey: .assignment)
    }

    public func encode(to encoder: any Encoder) throws {
        try team.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(assignment, forKey: .assignment)
    }
}

/// A user who holds an organization role (`user-role-assignment`).
public struct UserRoleAssignment: Sendable, Hashable, Codable, Identifiable {
    public var user: SimpleUser
    public var assignment: RoleAssignment?
    /// The teams the role comes through, for indirect assignments.
    public var inheritedFrom: [Team.Parent]?

    public var id: Int { user.id }

    enum CodingKeys: String, CodingKey {
        case assignment
        case inheritedFrom = "inherited_from"
    }

    public init(from decoder: any Decoder) throws {
        user = try SimpleUser(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assignment = try c.decodeIfPresent(RoleAssignment.self, forKey: .assignment)
        inheritedFrom = try c.decodeIfPresent([Team.Parent].self, forKey: .inheritedFrom)
    }

    public func encode(to encoder: any Encoder) throws {
        try user.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(assignment, forKey: .assignment)
        try c.encodeIfPresent(inheritedFrom, forKey: .inheritedFrom)
    }
}

// MARK: Fine-grained personal access tokens

/// A fine-grained token's access to an organization's resources.
public struct TokenAccess: Sendable, Hashable, Codable {
    /// Permission name to level, such as `"members": "read"`.
    public var organization: [String: String]?
    public var repository: [String: String]?
    public var other: [String: String]?
}

/// Which repositories a fine-grained token can reach.
public struct TokenRepositorySelection: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let none: Self = "none"
    public static let all: Self = "all"
    public static let subset: Self = "subset"
}

/// A fine-grained token with approved access to an organization (`organization-programmatic-access-grant`).
public struct PersonalAccessTokenGrant: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var owner: SimpleUser
    public var repositorySelection: TokenRepositorySelection
    public var repositoriesURL: URL?
    public var permissions: TokenAccess
    public var accessGrantedAt: Date?
    public var tokenID: Int
    public var tokenName: String?
    public var tokenExpired: Bool
    public var tokenExpiresAt: Date?
    public var tokenLastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, owner, permissions
        case repositorySelection = "repository_selection"
        case repositoriesURL = "repositories_url"
        case accessGrantedAt = "access_granted_at"
        case tokenID = "token_id"
        case tokenName = "token_name"
        case tokenExpired = "token_expired"
        case tokenExpiresAt = "token_expires_at"
        case tokenLastUsedAt = "token_last_used_at"
    }
}

/// A fine-grained token waiting for approval to access an organization
/// (`organization-programmatic-access-grant-request`).
public struct PersonalAccessTokenRequest: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var reason: String?
    public var owner: SimpleUser
    public var repositorySelection: TokenRepositorySelection
    public var repositoriesURL: URL?
    public var permissions: TokenAccess
    public var createdAt: Date?
    public var tokenID: Int
    public var tokenName: String?
    public var tokenExpired: Bool
    public var tokenExpiresAt: Date?
    public var tokenLastUsedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, reason, owner, permissions
        case repositorySelection = "repository_selection"
        case repositoriesURL = "repositories_url"
        case createdAt = "created_at"
        case tokenID = "token_id"
        case tokenName = "token_name"
        case tokenExpired = "token_expired"
        case tokenExpiresAt = "token_expires_at"
        case tokenLastUsedAt = "token_last_used_at"
    }
}

/// Narrows lists of fine-grained tokens and token requests.
public struct TokenFilter: Sendable, Hashable {
    /// Up to 10 owner logins.
    public var owners: [String]
    public var repository: String?
    /// A permission such as `issues_read`.
    public var permission: String?
    public var lastUsedBefore: Date?
    public var lastUsedAfter: Date?
    /// Up to 50 token IDs.
    public var tokenIDs: [Int]
    /// Sorts by creation date.
    public var ascending: Bool

    public init(
        owners: [String] = [], repository: String? = nil, permission: String? = nil, lastUsedBefore: Date? = nil,
        lastUsedAfter: Date? = nil, tokenIDs: [Int] = [], ascending: Bool = false
    ) {
        self.owners = owners
        self.repository = repository
        self.permission = permission
        self.lastUsedBefore = lastUsedBefore
        self.lastUsedAfter = lastUsedAfter
        self.tokenIDs = tokenIDs
        self.ascending = ascending
    }

    func query(perPage: Int) -> [URLQueryItem] {
        var items: [URLQueryItem] = .query(
            ("sort", "created_at"), ("direction", ascending ? "asc" : "desc"),
            ("repository", repository), ("permission", permission),
            ("last_used_before", lastUsedBefore?.ISO8601Format()), ("last_used_after", lastUsedAfter?.ISO8601Format()),
            ("per_page", perPage))
        items += owners.map { URLQueryItem(name: "owner[]", value: $0) }
        items += tokenIDs.map { URLQueryItem(name: "token_id[]", value: String($0)) }
        return items
    }
}

/// A decision on a token request.
public enum TokenRequestDecision: String, Sendable, Hashable, Encodable {
    case approve, deny
}
