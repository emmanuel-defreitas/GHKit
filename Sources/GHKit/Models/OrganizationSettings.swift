import Foundation

// MARK: Custom properties

/// A custom property that repositories in an organization can set (`custom-property`).
public struct CustomProperty: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var valueType: CustomPropertyType
    public var required: Bool?
    /// Used for repositories that don't set a value. Needed when `required` is `true`.
    public var defaultValue: PropertyValue?
    public var description: String?
    /// The choices, for `.singleSelect` and `.multiSelect` properties.
    public var allowedValues: [String]?
    /// `org_actors`, or `org_and_repo_actors` to let repository admins set values too.
    public var valuesEditableBy: String?
    /// Makes every repository choose a value instead of falling back to the default.
    public var requireExplicitValues: Bool?
    /// `organization` or `enterprise`. Set by GitHub.
    public var sourceType: String?
    public var url: URL?

    public var id: String { name }

    public init(
        name: String, valueType: CustomPropertyType, required: Bool? = nil, defaultValue: PropertyValue? = nil,
        description: String? = nil, allowedValues: [String]? = nil, valuesEditableBy: String? = nil,
        requireExplicitValues: Bool? = nil
    ) {
        self.name = name
        self.valueType = valueType
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
        self.allowedValues = allowedValues
        self.valuesEditableBy = valuesEditableBy
        self.requireExplicitValues = requireExplicitValues
    }

    enum CodingKeys: String, CodingKey {
        case name = "property_name"
        case valueType = "value_type"
        case required, description, url
        case defaultValue = "default_value"
        case allowedValues = "allowed_values"
        case valuesEditableBy = "values_editable_by"
        case requireExplicitValues = "require_explicit_values"
        case sourceType = "source_type"
    }
}

/// The kind of value a custom property holds.
public struct CustomPropertyType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let string: Self = "string"
    public static let singleSelect: Self = "single_select"
    public static let multiSelect: Self = "multi_select"
    public static let trueFalse: Self = "true_false"
    public static let url: Self = "url"
}

/// A custom property value: one string, or a list for multi-select properties.
public enum PropertyValue: Sendable, Hashable, Codable, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    case string(String)
    case list([String])

    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: String...) { self = .list(elements) }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([String].self) {
            self = .list(list)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .list(let values): try container.encode(values)
        }
    }
}

/// A property and its value on a repository (`custom-property-value`).
public struct CustomPropertyValue: Sendable, Hashable, Codable {
    public var name: String
    /// `nil` removes the value, so the property falls back to its default.
    public var value: PropertyValue?

    public init(_ name: String, _ value: PropertyValue?) {
        self.name = name
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case name = "property_name"
        case value
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        // GitHub needs an explicit null to unset a value.
        try c.encode(value, forKey: .value)
    }
}

/// A repository's custom property values (`org-repo-custom-property-values`).
public struct RepositoryPropertyValues: Sendable, Hashable, Codable, Identifiable {
    public var repositoryID: Int
    public var repositoryName: String
    public var repositoryFullName: String
    public var properties: [CustomPropertyValue]

    public var id: Int { repositoryID }

    /// The value of one property, if the repository has it.
    public subscript(property: String) -> PropertyValue? {
        properties.first { $0.name == property }?.value
    }

    enum CodingKeys: String, CodingKey {
        case properties
        case repositoryID = "repository_id"
        case repositoryName = "repository_name"
        case repositoryFullName = "repository_full_name"
    }
}

/// A property whose values a GitHub App manages from outside GitHub (`external-property`).
public struct ExternalProperty: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var id: String { name }

    enum CodingKeys: String, CodingKey { case name = "property_name" }
}

/// A GitHub App installation registered to manage external properties
/// (`organization-external-property-installation`).
public struct ExternalPropertyInstallation: Sendable, Hashable, Codable, Identifiable {
    public var displayName: String
    public var installationID: Int

    public var id: Int { installationID }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case installation
    }

    private struct Installation: Codable { let id: Int }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decode(String.self, forKey: .displayName)
        installationID = try c.decode(Installation.self, forKey: .installation).id
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(Installation(id: installationID), forKey: .installation)
    }
}

// MARK: Immutable releases

/// Which repositories must use immutable releases (`immutable-releases-organization-settings`).
public struct ImmutableReleasesSettings: Sendable, Hashable, Codable {
    public var enforcedRepositories: RepositoryScope
    /// Lists the chosen repositories when `enforcedRepositories` is `.selected`.
    public var selectedRepositoriesURL: URL?

    enum CodingKeys: String, CodingKey {
        case enforcedRepositories = "enforced_repositories"
        case selectedRepositoriesURL = "selected_repositories_url"
    }
}

/// All repositories, none, or a chosen set.
public struct RepositoryScope: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let all: Self = "all"
    public static let none: Self = "none"
    public static let selected: Self = "selected"
}

/// Which repositories to enforce immutable releases on.
public enum ImmutableReleasesPolicy: Sendable, Hashable, Encodable {
    case all
    case none
    case selected(repositoryIDs: [Int])

    enum CodingKeys: String, CodingKey {
        case enforcedRepositories = "enforced_repositories"
        case selectedRepositoryIDs = "selected_repository_ids"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .all: try c.encode(RepositoryScope.all, forKey: .enforcedRepositories)
        case .none: try c.encode(RepositoryScope.none, forKey: .enforcedRepositories)
        case .selected(let ids):
            try c.encode(RepositoryScope.selected, forKey: .enforcedRepositories)
            try c.encode(ids, forKey: .selectedRepositoryIDs)
        }
    }
}

// MARK: API insights

/// Who made API requests, for API insights.
public enum APIActor: Sendable, Hashable {
    case installation(id: Int)
    case classicToken(id: Int)
    case fineGrainedToken(id: Int)
    case oauthApp(id: Int)
    /// A GitHub App acting for a user.
    case appUserToServer(id: Int)

    var pathComponent: String {
        switch self {
        case .installation(let id): "installation/\(id)"
        case .classicToken(let id): "classic_pat/\(id)"
        case .fineGrainedToken(let id): "fine_grained_pat/\(id)"
        case .oauthApp(let id): "oauth_app/\(id)"
        case .appUserToServer(let id): "github_app_user_to_server/\(id)"
        }
    }
}

/// Whose API requests to count.
public enum APIUsageScope: Sendable, Hashable {
    /// Every request made against the organization.
    case organization
    /// Requests made by one user, by user ID.
    case user(id: Int)
    case actor(APIActor)

    func path(_ base: String) -> String {
        switch self {
        case .organization: base
        case .user(let id): "\(base)/users/\(id)"
        case .actor(let actor): "\(base)/\(actor.pathComponent)"
        }
    }
}

/// The time window API insights cover.
///
/// GitHub keeps about 30 days of data.
public struct APIUsageWindow: Sendable, Hashable {
    public var start: Date
    /// `nil` means now.
    public var end: Date?

    public init(from start: Date, to end: Date? = nil) {
        self.start = start
        self.end = end
    }

    /// The last `seconds` up to now.
    public static func last(_ seconds: TimeInterval) -> Self { Self(from: Date(timeIntervalSinceNow: -seconds)) }

    var query: [URLQueryItem] {
        .query(("min_timestamp", start.ISO8601Format()), ("max_timestamp", end?.ISO8601Format()))
    }
}

/// How finely to break down API usage over time.
public struct APIUsageInterval: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fiveMinutes: Self = "5m"
    public static let tenMinutes: Self = "10m"
    public static let hour: Self = "1h"
}

/// What to sort API insights lists by.
public struct APIUsageSort: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let totalRequests: Self = "total_request_count"
    public static let rateLimitedRequests: Self = "rate_limited_request_count"
    public static let lastRequest: Self = "last_request_timestamp"
    public static let lastRateLimited: Self = "last_rate_limited_timestamp"
    /// Subject and actor lists only.
    public static let subjectName: Self = "subject_name"
    /// Route lists only.
    public static let route: Self = "api_route"
    /// Route lists only.
    public static let httpMethod: Self = "http_method"
}

/// Request totals for a time window (`api-insights-summary-stats`).
public struct APIUsageSummary: Sendable, Hashable, Codable {
    public var totalRequestCount: Int?
    public var rateLimitedRequestCount: Int?

    enum CodingKeys: String, CodingKey {
        case totalRequestCount = "total_request_count"
        case rateLimitedRequestCount = "rate_limited_request_count"
    }
}

/// Request totals for one slice of time (`api-insights-time-stats`).
public struct APIUsageSample: Sendable, Hashable, Codable {
    public var timestamp: Date
    public var totalRequestCount: Int?
    public var rateLimitedRequestCount: Int?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case totalRequestCount = "total_request_count"
        case rateLimitedRequestCount = "rate_limited_request_count"
    }
}

/// Usage of one API route by an actor (`api-insights-route-stats`).
public struct APIRouteUsage: Sendable, Hashable, Codable {
    public var httpMethod: String?
    /// A route template, such as `/repositories/:repository_id`.
    public var apiRoute: String?
    public var totalRequestCount: Int?
    public var rateLimitedRequestCount: Int?
    public var lastRequestAt: Date?
    public var lastRateLimitedAt: Date?

    enum CodingKeys: String, CodingKey {
        case httpMethod = "http_method"
        case apiRoute = "api_route"
        case totalRequestCount = "total_request_count"
        case rateLimitedRequestCount = "rate_limited_request_count"
        case lastRequestAt = "last_request_timestamp"
        case lastRateLimitedAt = "last_rate_limited_timestamp"
    }
}

/// Usage against one subject, such as a repository (`api-insights-subject-stats`).
public struct APISubjectUsage: Sendable, Hashable, Codable {
    public var subjectType: String?
    public var subjectName: String?
    public var subjectID: Int?
    public var totalRequestCount: Int?
    public var rateLimitedRequestCount: Int?
    public var lastRequestAt: Date?
    public var lastRateLimitedAt: Date?

    enum CodingKeys: String, CodingKey {
        case subjectType = "subject_type"
        case subjectName = "subject_name"
        case subjectID = "subject_id"
        case totalRequestCount = "total_request_count"
        case rateLimitedRequestCount = "rate_limited_request_count"
        case lastRequestAt = "last_request_timestamp"
        case lastRateLimitedAt = "last_rate_limited_timestamp"
    }
}

/// Usage by one actor on behalf of a user (`api-insights-user-stats`).
public struct APIActorUsage: Sendable, Hashable, Codable {
    /// Such as `installation` or `oauth_app`.
    public var actorType: String?
    public var actorName: String?
    public var actorID: Int?
    public var integrationID: Int?
    public var oauthApplicationID: Int?
    public var totalRequestCount: Int?
    public var rateLimitedRequestCount: Int?
    public var lastRequestAt: Date?
    public var lastRateLimitedAt: Date?

    enum CodingKeys: String, CodingKey {
        case actorType = "actor_type"
        case actorName = "actor_name"
        case actorID = "actor_id"
        case integrationID = "integration_id"
        case oauthApplicationID = "oauth_application_id"
        case totalRequestCount = "total_request_count"
        case rateLimitedRequestCount = "rate_limited_request_count"
        case lastRequestAt = "last_request_timestamp"
        case lastRateLimitedAt = "last_rate_limited_timestamp"
    }
}
