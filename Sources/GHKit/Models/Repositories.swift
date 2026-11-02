import Foundation

/// A repository (`minimal-repository`, `repository`, `full-repository`).
///
/// Lists return a subset of fields. Fetch one repository to get settings, license, parent, and source.
public struct Repository: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    /// `owner/name`.
    public var fullName: String
    public var owner: SimpleUser
    public var isPrivate: Bool
    public var htmlURL: URL?
    public var url: URL?
    public var description: String?
    public var homepage: String?
    public var language: String?
    public var isFork: Bool?
    public var isTemplate: Bool?
    public var isArchived: Bool?
    public var isDisabled: Bool?
    public var visibility: RepositoryVisibility?
    public var defaultBranch: String?
    public var topics: [String]?
    public var license: LicenseSummary?
    public var forksCount: Int?
    public var stargazersCount: Int?
    public var watchersCount: Int?
    public var subscribersCount: Int?
    public var networkCount: Int?
    public var openIssuesCount: Int?
    /// Size in kilobytes.
    public var size: Int?
    public var hasIssues: Bool?
    public var hasProjects: Bool?
    public var hasWiki: Bool?
    public var hasPages: Bool?
    public var hasDiscussions: Bool?
    public var hasDownloads: Bool?
    public var hasPullRequests: Bool?
    public var cloneURL: URL?
    public var sshURL: String?
    public var svnURL: URL?
    public var mirrorURL: URL?
    public var pushedAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?
    /// What the caller, or the team being checked, can do. Only set in some responses.
    public var permissions: RepositoryPermissions?
    /// The role name behind `permissions`, such as `write` or a custom role.
    public var roleName: String?

    // Settings, set when you fetch one repository you can administer
    public var allowMergeCommit: Bool?
    public var allowSquashMerge: Bool?
    public var allowRebaseMerge: Bool?
    public var allowAutoMerge: Bool?
    public var allowUpdateBranch: Bool?
    public var allowForking: Bool?
    public var deleteBranchOnMerge: Bool?
    public var webCommitSignoffRequired: Bool?
    public var squashMergeCommitTitle: SquashMergeCommitTitle?
    public var squashMergeCommitMessage: SquashMergeCommitMessage?
    public var mergeCommitTitle: MergeCommitTitle?
    public var mergeCommitMessage: MergeCommitMessage?
    public var securityAndAnalysis: SecurityAndAnalysis?
    public var codeOfConduct: CodeOfConductSummary?
    public var customProperties: [String: PropertyValue]?
    /// The organization that owns the repository, when it isn't a user.
    public var organization: SimpleUser?

    private var parentStorage: Indirect<Repository>?
    private var sourceStorage: Indirect<Repository>?
    private var templateStorage: Indirect<Repository>?

    /// For a fork, the repository it was forked from.
    public var parent: Repository? { parentStorage?.value }
    /// For a fork, the root of the fork network.
    public var source: Repository? { sourceStorage?.value }
    /// The template the repository was created from.
    public var templateRepository: Repository? { templateStorage?.value }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, url, description, homepage, language, visibility, topics, size, license, permissions
        case organization
        case nodeID = "node_id"
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case isFork = "fork"
        case isTemplate = "is_template"
        case isArchived = "archived"
        case isDisabled = "disabled"
        case defaultBranch = "default_branch"
        case forksCount = "forks_count"
        case stargazersCount = "stargazers_count"
        case watchersCount = "watchers_count"
        case subscribersCount = "subscribers_count"
        case networkCount = "network_count"
        case openIssuesCount = "open_issues_count"
        case hasIssues = "has_issues"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case hasDiscussions = "has_discussions"
        case hasDownloads = "has_downloads"
        case hasPullRequests = "has_pull_requests"
        case cloneURL = "clone_url"
        case sshURL = "ssh_url"
        case svnURL = "svn_url"
        case mirrorURL = "mirror_url"
        case pushedAt = "pushed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case roleName = "role_name"
        case allowMergeCommit = "allow_merge_commit"
        case allowSquashMerge = "allow_squash_merge"
        case allowRebaseMerge = "allow_rebase_merge"
        case allowAutoMerge = "allow_auto_merge"
        case allowUpdateBranch = "allow_update_branch"
        case allowForking = "allow_forking"
        case deleteBranchOnMerge = "delete_branch_on_merge"
        case webCommitSignoffRequired = "web_commit_signoff_required"
        case squashMergeCommitTitle = "squash_merge_commit_title"
        case squashMergeCommitMessage = "squash_merge_commit_message"
        case mergeCommitTitle = "merge_commit_title"
        case mergeCommitMessage = "merge_commit_message"
        case securityAndAnalysis = "security_and_analysis"
        case codeOfConduct = "code_of_conduct"
        case customProperties = "custom_properties"
        case parentStorage = "parent"
        case sourceStorage = "source"
        case templateStorage = "template_repository"
    }
}

/// Lets a value type hold another value of the same type, such as a fork's parent.
indirect enum Indirect<Value: Sendable & Hashable & Codable>: Sendable, Hashable, Codable {
    case value(Value)

    var value: Value {
        switch self {
        case .value(let value): value
        }
    }

    init(from decoder: any Decoder) throws { self = .value(try Value(from: decoder)) }
    func encode(to encoder: any Encoder) throws { try value.encode(to: encoder) }
}

/// Permission levels on a repository, from `pull` (read) up to `admin`.
public struct RepositoryPermissions: Sendable, Hashable, Codable {
    public var admin: Bool
    public var maintain: Bool?
    public var push: Bool
    public var triage: Bool?
    public var pull: Bool
}

/// Who can see a repository.
public struct RepositoryVisibility: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let `public`: Self = "public"
    public static let `private`: Self = "private"
    /// Visible to every member of the enterprise.
    public static let `internal`: Self = "internal"
}

/// A license as it appears on a repository (`license-simple`).
public struct LicenseSummary: Sendable, Hashable, Codable {
    /// Such as `mit`.
    public var key: String
    public var name: String
    /// Such as `MIT`. `NOASSERTION` when GitHub can't tell.
    public var spdxID: String?
    public var url: URL?
    public var nodeID: String?

    enum CodingKeys: String, CodingKey {
        case key, name, url
        case spdxID = "spdx_id"
        case nodeID = "node_id"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        name = try c.decode(String.self, forKey: .name)
        spdxID = try c.decodeIfPresent(String.self, forKey: .spdxID)
        // "Other" licenses have no URL, and some payloads send "" instead of null.
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
    }
}

/// A code of conduct as it appears on a repository (`code-of-conduct-simple`).
public struct CodeOfConductSummary: Sendable, Hashable, Codable {
    public var key: String
    public var name: String
    public var url: URL?
    public var htmlURL: URL?

    enum CodingKeys: String, CodingKey {
        case key, name, url
        case htmlURL = "html_url"
    }
}

/// Which security features are on (`security-and-analysis`).
public struct SecurityAndAnalysis: Sendable, Hashable, Codable {
    /// Feature to whether it's enabled.
    public var features: [SecurityFeature: Bool]

    public init(_ features: [SecurityFeature: Bool]) { self.features = features }

    public subscript(feature: SecurityFeature) -> Bool? { features[feature] }

    private struct Status: Codable {
        let status: String?

        init(_ enabled: Bool) { status = enabled ? "enabled" : "disabled" }

        init(from decoder: any Decoder) throws {
            // A few entries hold settings rather than a status; treat those as unknown.
            status = try? decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .status)
        }

        enum CodingKeys: String, CodingKey { case status }
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Status].self)
        features = Dictionary(
            uniqueKeysWithValues: raw.compactMap { key, value in
                value.status.map { (SecurityFeature(rawValue: key), $0 == "enabled") }
            })
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: features.map { ($0.key.rawValue, Status($0.value)) }))
    }
}

/// A repository security feature.
public struct SecurityFeature: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let advancedSecurity: Self = "advanced_security"
    public static let codeSecurity: Self = "code_security"
    public static let dependabotSecurityUpdates: Self = "dependabot_security_updates"
    public static let secretScanning: Self = "secret_scanning"
    public static let secretScanningPushProtection: Self = "secret_scanning_push_protection"
    public static let secretScanningNonProviderPatterns: Self = "secret_scanning_non_provider_patterns"
    public static let secretScanningAIDetection: Self = "secret_scanning_ai_detection"
    public static let secretScanningValidityChecks: Self = "secret_scanning_validity_checks"
}

/// The default title for squash merge commits.
public struct SquashMergeCommitTitle: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pullRequestTitle: Self = "PR_TITLE"
    /// The commit's title for one-commit pull requests, the pull request's title otherwise.
    public static let commitOrPullRequestTitle: Self = "COMMIT_OR_PR_TITLE"
}

/// The default message for squash merge commits.
public struct SquashMergeCommitMessage: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pullRequestBody: Self = "PR_BODY"
    public static let commitMessages: Self = "COMMIT_MESSAGES"
    public static let blank: Self = "BLANK"
}

/// The default title for merge commits.
public struct MergeCommitTitle: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pullRequestTitle: Self = "PR_TITLE"
    /// `Merge pull request #123 from branch-name`.
    public static let mergeMessage: Self = "MERGE_MESSAGE"
}

/// The default message for merge commits.
public struct MergeCommitMessage: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pullRequestBody: Self = "PR_BODY"
    public static let pullRequestTitle: Self = "PR_TITLE"
    public static let blank: Self = "BLANK"
}
