import Foundation

/// Someone who has committed to a repository (`contributor`).
///
/// Anonymous contributors, included on request, have only an email, a name, and a count.
public struct Contributor: Sendable, Hashable, Codable {
    public var login: String?
    public var id: Int?
    public var nodeID: String?
    public var avatarURL: URL?
    public var htmlURL: URL?
    /// `User`, `Bot`, or `Anonymous`.
    public var type: String
    public var contributions: Int
    public var email: String?
    public var name: String?

    public var isAnonymous: Bool { type == "Anonymous" }

    enum CodingKeys: String, CodingKey {
        case login, id, type, contributions, email, name
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }
}

/// A tag, with the commit it points to (`tag`).
public struct RepositoryTag: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var commit: CommitReference
    public var nodeID: String?
    public var zipballURL: URL?
    public var tarballURL: URL?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, commit
        case nodeID = "node_id"
        case zipballURL = "zipball_url"
        case tarballURL = "tarball_url"
    }
}

/// A commit SHA and its API URL.
public struct CommitReference: Sendable, Hashable, Codable {
    public var sha: String
    public var url: URL?
}

/// One change to a repository's branches (`activity`).
public struct RepositoryActivity: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    /// The commit SHA before the change.
    public var before: String
    /// The commit SHA after the change.
    public var after: String
    /// Such as `refs/heads/main`.
    public var ref: String
    public var timestamp: Date?
    public var activityType: RepositoryActivityType?
    public var actor: SimpleUser?

    enum CodingKeys: String, CodingKey {
        case id, before, after, ref, timestamp, actor
        case nodeID = "node_id"
        case activityType = "activity_type"
        // Older payloads use these names.
        case pushedAt = "pushed_at"
        case pusher
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
        before = try c.decode(String.self, forKey: .before)
        after = try c.decode(String.self, forKey: .after)
        ref = try c.decode(String.self, forKey: .ref)
        timestamp = try c.decodeIfPresent(Date.self, forKey: .timestamp) ?? c.decodeIfPresent(Date.self, forKey: .pushedAt)
        activityType = try c.decodeIfPresent(RepositoryActivityType.self, forKey: .activityType)
        actor = try c.decodeIfPresent(SimpleUser.self, forKey: .actor) ?? c.decodeIfPresent(SimpleUser.self, forKey: .pusher)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(nodeID, forKey: .nodeID)
        try c.encode(before, forKey: .before)
        try c.encode(after, forKey: .after)
        try c.encode(ref, forKey: .ref)
        try c.encodeIfPresent(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(activityType, forKey: .activityType)
        try c.encodeIfPresent(actor, forKey: .actor)
    }
}

/// The kind of branch change.
public struct RepositoryActivityType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let push: Self = "push"
    public static let forcePush: Self = "force_push"
    public static let branchCreation: Self = "branch_creation"
    public static let branchDeletion: Self = "branch_deletion"
    public static let pullRequestMerge: Self = "pr_merge"
    public static let mergeQueueMerge: Self = "merge_queue_merge"
}

/// Narrows repository activity.
public struct RepositoryActivityFilter: Sendable, Hashable {
    /// A branch name or full ref, such as `main` or `refs/heads/main`.
    public var ref: String?
    /// A login.
    public var actor: String?
    public var type: RepositoryActivityType?
    /// Only activity within the last `day`, `week`, `month`, `quarter`, or `year`.
    public var timePeriod: String?
    public var ascending: Bool

    public init(
        ref: String? = nil, actor: String? = nil, type: RepositoryActivityType? = nil, timePeriod: String? = nil,
        ascending: Bool = false
    ) {
        self.ref = ref
        self.actor = actor
        self.type = type
        self.timePeriod = timePeriod
        self.ascending = ascending
    }

    func query(perPage: Int) -> [URLQueryItem] {
        .query(
            ("ref", ref), ("actor", actor), ("activity_type", type), ("time_period", timePeriod),
            ("direction", ascending ? "asc" : "desc"), ("per_page", perPage))
    }
}

/// How a repository scores on GitHub's community checklist (`community-profile`).
public struct CommunityProfile: Sendable, Hashable, Codable {
    /// 0 to 100.
    public var healthPercentage: Int
    public var description: String?
    public var documentation: String?
    public var files: Files
    public var updatedAt: Date?
    public var contentReportsEnabled: Bool?

    /// Each recommended file, or `nil` if the repository doesn't have it.
    public struct Files: Sendable, Hashable, Codable {
        public var codeOfConduct: CodeOfConductSummary?
        public var codeOfConductFile: File?
        public var contributing: File?
        public var issueTemplate: File?
        public var pullRequestTemplate: File?
        public var license: LicenseSummary?
        public var readme: File?

        enum CodingKeys: String, CodingKey {
            case contributing, license, readme
            case codeOfConduct = "code_of_conduct"
            case codeOfConductFile = "code_of_conduct_file"
            case issueTemplate = "issue_template"
            case pullRequestTemplate = "pull_request_template"
        }
    }

    public struct File: Sendable, Hashable, Codable {
        public var url: URL?
        public var htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case url
            case htmlURL = "html_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case description, documentation, files
        case healthPercentage = "health_percentage"
        case updatedAt = "updated_at"
        case contentReportsEnabled = "content_reports_enabled"
    }
}

/// Whether Dependabot opens pull requests for vulnerable dependencies (`check-automated-security-fixes`).
public struct DependabotSecurityUpdatesStatus: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    /// Whether updates are paused, which happens when a repository is inactive.
    public var isPaused: Bool

    enum CodingKeys: String, CodingKey {
        case isEnabled = "enabled"
        case isPaused = "paused"
    }
}

/// Whether a repository's releases are immutable (`check-immutable-releases`).
public struct ImmutableReleasesStatus: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    /// Whether the organization or enterprise requires it, so the repository can't turn it off.
    public var isEnforcedByOwner: Bool

    enum CodingKeys: String, CodingKey {
        case isEnabled = "enabled"
        case isEnforcedByOwner = "enforced_by_owner"
    }
}
