import Foundation

/// A named set of rules for branches, tags, pushes, or repositories (`repository-ruleset`).
public struct Ruleset: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var name: String
    public var target: RulesetTarget?
    /// `Repository`, `Organization`, or `Enterprise`.
    public var sourceType: String?
    /// The repository (`owner/name`) or account that owns the ruleset.
    public var source: String
    public var enforcement: RulesetEnforcement
    public var bypassActors: [BypassActor]?
    /// How the signed-in user can bypass the ruleset: `always`, `pull_requests_only`, `never`, or `exempt`.
    /// Only repository endpoints return it.
    public var currentUserCanBypass: String?
    public var nodeID: String?
    public var conditions: RulesetConditions?
    /// Missing from list responses. Fetch the ruleset to see its rules.
    public var rules: [RepositoryRule]?
    public var htmlURL: URL?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, target, source, enforcement, conditions, rules
        case sourceType = "source_type"
        case bypassActors = "bypass_actors"
        case currentUserCanBypass = "current_user_can_bypass"
        case nodeID = "node_id"
        case links = "_links"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    private struct Links: Codable { var html: Link? }
    private struct Link: Codable { var href: URL? }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        target = try c.decodeIfPresent(RulesetTarget.self, forKey: .target)
        sourceType = try c.decodeIfPresent(String.self, forKey: .sourceType)
        source = try c.decode(String.self, forKey: .source)
        enforcement = try c.decode(RulesetEnforcement.self, forKey: .enforcement)
        bypassActors = try c.decodeIfPresent([BypassActor].self, forKey: .bypassActors)
        currentUserCanBypass = try c.decodeIfPresent(String.self, forKey: .currentUserCanBypass)
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
        conditions = try c.decodeIfPresent(RulesetConditions.self, forKey: .conditions)
        rules = try c.decodeIfPresent([RepositoryRule].self, forKey: .rules)
        htmlURL = try c.decodeIfPresent(Links.self, forKey: .links)?.html?.href
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(target, forKey: .target)
        try c.encodeIfPresent(sourceType, forKey: .sourceType)
        try c.encode(source, forKey: .source)
        try c.encode(enforcement, forKey: .enforcement)
        try c.encodeIfPresent(bypassActors, forKey: .bypassActors)
        try c.encodeIfPresent(currentUserCanBypass, forKey: .currentUserCanBypass)
        try c.encodeIfPresent(nodeID, forKey: .nodeID)
        try c.encodeIfPresent(conditions, forKey: .conditions)
        try c.encodeIfPresent(rules, forKey: .rules)
        if let htmlURL { try c.encode(Links(html: Link(href: htmlURL)), forKey: .links) }
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

/// What a ruleset applies to.
public struct RulesetTarget: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let branch: Self = "branch"
    public static let tag: Self = "tag"
    /// Pushes to a repository and its forks, such as file path and size limits.
    public static let push: Self = "push"
    /// Repository settings such as renaming and visibility.
    public static let repository: Self = "repository"
}

/// Whether a ruleset is on.
public struct RulesetEnforcement: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let disabled: Self = "disabled"
    public static let active: Self = "active"
    /// Reports what would fail without blocking anything. GitHub Enterprise only.
    public static let evaluate: Self = "evaluate"
}

/// Someone who can skip a ruleset's rules (`repository-ruleset-bypass-actor`).
public struct BypassActor: Sendable, Hashable, Codable {
    /// Required for apps, repository roles, teams, and users.
    public var actorID: Int?
    public var actorType: ActorType
    public var bypassMode: BypassMode?

    public init(actorID: Int?, actorType: ActorType, bypassMode: BypassMode? = .always) {
        self.actorID = actorID
        self.actorType = actorType
        self.bypassMode = bypassMode
    }

    public static func team(_ id: Int, mode: BypassMode = .always) -> Self { Self(actorID: id, actorType: .team, bypassMode: mode) }
    public static func user(_ id: Int, mode: BypassMode = .always) -> Self { Self(actorID: id, actorType: .user, bypassMode: mode) }
    /// A GitHub App, by app ID.
    public static func app(_ id: Int, mode: BypassMode = .always) -> Self { Self(actorID: id, actorType: .integration, bypassMode: mode) }
    /// A repository role, such as 5 for `admin`, 4 for `write`, or 2 for `maintain`.
    public static func repositoryRole(_ id: Int, mode: BypassMode = .always) -> Self {
        Self(actorID: id, actorType: .repositoryRole, bypassMode: mode)
    }
    public static func organizationAdmins(mode: BypassMode = .always) -> Self {
        Self(actorID: nil, actorType: .organizationAdmin, bypassMode: mode)
    }
    public static func deployKeys(mode: BypassMode = .always) -> Self { Self(actorID: nil, actorType: .deployKey, bypassMode: mode) }

    /// The kind of actor.
    public struct ActorType: OpenEnum {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let integration: Self = "Integration"
        public static let organizationAdmin: Self = "OrganizationAdmin"
        public static let repositoryRole: Self = "RepositoryRole"
        public static let team: Self = "Team"
        public static let deployKey: Self = "DeployKey"
        public static let user: Self = "User"
    }

    /// When an actor can bypass.
    public struct BypassMode: OpenEnum {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let always: Self = "always"
        /// Only by merging a pull request. Not for deploy keys.
        public static let pullRequest: Self = "pull_request"
        /// Rules aren't evaluated for this actor at all.
        public static let exempt: Self = "exempt"
    }

    enum CodingKeys: String, CodingKey {
        case actorID = "actor_id"
        case actorType = "actor_type"
        case bypassMode = "bypass_mode"
    }
}

/// Which refs and repositories a ruleset covers.
///
/// Repository rulesets use ``refName`` only. Organization rulesets also pick repositories by name, ID, or property.
public struct RulesetConditions: Sendable, Hashable, Codable {
    /// Ref names or patterns, such as `refs/heads/main`, `~DEFAULT_BRANCH`, or `~ALL`.
    public var refName: Patterns?
    /// Repository names or patterns, such as `~ALL`.
    public var repositoryName: RepositoryNames?
    public var repositoryIDs: [Int]?
    public var repositoryProperty: Properties?

    public init(
        refName: Patterns? = nil, repositoryName: RepositoryNames? = nil, repositoryIDs: [Int]? = nil,
        repositoryProperty: Properties? = nil
    ) {
        self.refName = refName
        self.repositoryName = repositoryName
        self.repositoryIDs = repositoryIDs
        self.repositoryProperty = repositoryProperty
    }

    /// Patterns to include and exclude.
    public struct Patterns: Sendable, Hashable, Codable {
        public var include: [String]
        public var exclude: [String]

        public init(include: [String], exclude: [String] = []) {
            self.include = include
            self.exclude = exclude
        }

        enum CodingKeys: String, CodingKey { case include, exclude }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            include = try c.decodeIfPresent([String].self, forKey: .include) ?? []
            exclude = try c.decodeIfPresent([String].self, forKey: .exclude) ?? []
        }
    }

    /// Repository name patterns.
    public struct RepositoryNames: Sendable, Hashable, Codable {
        public var include: [String]
        public var exclude: [String]
        /// Whether renaming a targeted repository is blocked.
        public var isProtected: Bool?

        public init(include: [String], exclude: [String] = [], isProtected: Bool? = nil) {
            self.include = include
            self.exclude = exclude
            self.isProtected = isProtected
        }

        enum CodingKeys: String, CodingKey {
            case include, exclude
            case isProtected = "protected"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            include = try c.decodeIfPresent([String].self, forKey: .include) ?? []
            exclude = try c.decodeIfPresent([String].self, forKey: .exclude) ?? []
            isProtected = try c.decodeIfPresent(Bool.self, forKey: .isProtected)
        }
    }

    /// Custom property values to include and exclude. Every included property must match.
    public struct Properties: Sendable, Hashable, Codable {
        public var include: [Property]
        public var exclude: [Property]

        public init(include: [Property], exclude: [Property] = []) {
            self.include = include
            self.exclude = exclude
        }

        enum CodingKeys: String, CodingKey { case include, exclude }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            include = try c.decodeIfPresent([Property].self, forKey: .include) ?? []
            exclude = try c.decodeIfPresent([Property].self, forKey: .exclude) ?? []
        }
    }

    /// A repository property and the values that match it.
    public struct Property: Sendable, Hashable, Codable {
        public var name: String
        public var values: [String]
        /// `custom` (the default) or `system`.
        public var source: String?

        public init(_ name: String, values: [String], source: String? = nil) {
            self.name = name
            self.values = values
            self.source = source
        }

        enum CodingKeys: String, CodingKey {
            case name, source
            case values = "property_values"
        }
    }

    enum CodingKeys: String, CodingKey {
        case refName = "ref_name"
        case repositoryName = "repository_name"
        case repositoryID = "repository_id"
        case repositoryProperty = "repository_property"
    }

    private struct RepositoryIDs: Codable {
        var repositoryIDs: [Int]?
        enum CodingKeys: String, CodingKey { case repositoryIDs = "repository_ids" }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        refName = try c.decodeIfPresent(Patterns.self, forKey: .refName)
        repositoryName = try c.decodeIfPresent(RepositoryNames.self, forKey: .repositoryName)
        repositoryIDs = try c.decodeIfPresent(RepositoryIDs.self, forKey: .repositoryID)?.repositoryIDs
        repositoryProperty = try c.decodeIfPresent(Properties.self, forKey: .repositoryProperty)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(refName, forKey: .refName)
        try c.encodeIfPresent(repositoryName, forKey: .repositoryName)
        try c.encodeIfPresent(repositoryIDs.map { RepositoryIDs(repositoryIDs: $0) }, forKey: .repositoryID)
        try c.encodeIfPresent(repositoryProperty, forKey: .repositoryProperty)
    }
}

// MARK: - Rules

/// One rule in a ruleset (`repository-rule`).
///
/// Rule types GitHub adds later decode as ``other(type:parameters:)``.
public enum RepositoryRule: Sendable, Hashable, Codable {
    /// Only bypass actors can create matching refs.
    case creation
    /// Only bypass actors can update matching refs.
    case update(allowsFetchAndMerge: Bool = false)
    /// Only bypass actors can delete matching refs.
    case deletion
    case requiredLinearHistory
    case requiredSignatures
    /// Blocks force pushes.
    case nonFastForward
    /// Environments a change must deploy to before it can merge.
    case requiredDeployments(environments: [String])
    case pullRequest(PullRequestRule)
    case requiredStatusChecks(StatusChecksRule)
    case mergeQueue(MergeQueueRule)
    case commitMessagePattern(PatternRule)
    case commitAuthorEmailPattern(PatternRule)
    case committerEmailPattern(PatternRule)
    case branchNamePattern(PatternRule)
    case tagNamePattern(PatternRule)
    /// Workflows that must pass before a ref updates.
    case workflows(WorkflowsRule)
    case codeScanning(tools: [CodeScanningTool])
    /// Blocks merging when code quality findings reach a severity: `errors`, `warnings`, `notes`, or `all`.
    case codeQuality(severity: String)
    case codeCoverage(CodeCoverageRule)
    /// Requests a Copilot review on new pull requests.
    case copilotCodeReview(CopilotReviewRule)
    case licenseComplianceScanning
    /// Blocks pushes that change matching paths.
    case filePathRestriction(restricted: [String], ignored: [String] = [])
    case maxFilePathLength(Int)
    /// Blocks pushes that add files with these extensions, such as `*.exe`.
    case fileExtensionRestriction([String])
    /// Blocks pushes with files over a size, in megabytes (1 to 100). Git LFS files don't count.
    case maxFileSize(megabytes: Int, ignored: [String] = [])
    /// A rule type GHKit doesn't model yet.
    case other(type: String, parameters: JSONValue?)

    /// GitHub's name for the rule type, such as `pull_request`.
    public var type: String {
        switch self {
        case .creation: "creation"
        case .update: "update"
        case .deletion: "deletion"
        case .requiredLinearHistory: "required_linear_history"
        case .requiredSignatures: "required_signatures"
        case .nonFastForward: "non_fast_forward"
        case .requiredDeployments: "required_deployments"
        case .pullRequest: "pull_request"
        case .requiredStatusChecks: "required_status_checks"
        case .mergeQueue: "merge_queue"
        case .commitMessagePattern: "commit_message_pattern"
        case .commitAuthorEmailPattern: "commit_author_email_pattern"
        case .committerEmailPattern: "committer_email_pattern"
        case .branchNamePattern: "branch_name_pattern"
        case .tagNamePattern: "tag_name_pattern"
        case .workflows: "workflows"
        case .codeScanning: "code_scanning"
        case .codeQuality: "code_quality"
        case .codeCoverage: "code_coverage"
        case .copilotCodeReview: "copilot_code_review"
        case .licenseComplianceScanning: "license_compliance_scanning"
        case .filePathRestriction: "file_path_restriction"
        case .maxFilePathLength: "max_file_path_length"
        case .fileExtensionRestriction: "file_extension_restriction"
        case .maxFileSize: "max_file_size"
        case .other(let type, _): type
        }
    }

    enum CodingKeys: String, CodingKey { case type, parameters }

    enum ParameterKeys: String, CodingKey {
        case updateAllowsFetchAndMerge = "update_allows_fetch_and_merge"
        case requiredDeploymentEnvironments = "required_deployment_environments"
        case codeScanningTools = "code_scanning_tools"
        case severity
        case restrictedFilePaths = "restricted_file_paths"
        case ignoredFilePaths = "ignored_file_paths"
        case maxFilePathLength = "max_file_path_length"
        case restrictedFileExtensions = "restricted_file_extensions"
        case maxFileSize = "max_file_size"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        func parameters<T: Decodable>(_: T.Type = T.self) throws -> T { try c.decode(T.self, forKey: .parameters) }
        func keyed() throws -> KeyedDecodingContainer<ParameterKeys> {
            try c.nestedContainer(keyedBy: ParameterKeys.self, forKey: .parameters)
        }
        switch type {
        case "creation": self = .creation
        case "update":
            let allows = c.contains(.parameters) ? try keyed().decodeIfPresent(Bool.self, forKey: .updateAllowsFetchAndMerge) : nil
            self = .update(allowsFetchAndMerge: allows ?? false)
        case "deletion": self = .deletion
        case "required_linear_history": self = .requiredLinearHistory
        case "required_signatures": self = .requiredSignatures
        case "non_fast_forward": self = .nonFastForward
        case "required_deployments":
            self = .requiredDeployments(environments: try keyed().decode([String].self, forKey: .requiredDeploymentEnvironments))
        case "pull_request": self = .pullRequest(try parameters())
        case "required_status_checks": self = .requiredStatusChecks(try parameters())
        case "merge_queue": self = .mergeQueue(try parameters())
        case "commit_message_pattern": self = .commitMessagePattern(try parameters())
        case "commit_author_email_pattern": self = .commitAuthorEmailPattern(try parameters())
        case "committer_email_pattern": self = .committerEmailPattern(try parameters())
        case "branch_name_pattern": self = .branchNamePattern(try parameters())
        case "tag_name_pattern": self = .tagNamePattern(try parameters())
        case "workflows": self = .workflows(try parameters())
        case "code_scanning": self = .codeScanning(tools: try keyed().decode([CodeScanningTool].self, forKey: .codeScanningTools))
        case "code_quality": self = .codeQuality(severity: try keyed().decode(String.self, forKey: .severity))
        case "code_coverage": self = .codeCoverage(try parameters())
        case "copilot_code_review": self = .copilotCodeReview(try c.decodeIfPresent(CopilotReviewRule.self, forKey: .parameters) ?? .init())
        case "license_compliance_scanning": self = .licenseComplianceScanning
        case "file_path_restriction":
            let p = try keyed()
            self = .filePathRestriction(
                restricted: try p.decode([String].self, forKey: .restrictedFilePaths),
                ignored: try p.decodeIfPresent([String].self, forKey: .ignoredFilePaths) ?? [])
        case "max_file_path_length": self = .maxFilePathLength(try keyed().decode(Int.self, forKey: .maxFilePathLength))
        case "file_extension_restriction":
            self = .fileExtensionRestriction(try keyed().decode([String].self, forKey: .restrictedFileExtensions))
        case "max_file_size":
            let p = try keyed()
            self = .maxFileSize(
                megabytes: try p.decode(Int.self, forKey: .maxFileSize),
                ignored: try p.decodeIfPresent([String].self, forKey: .ignoredFilePaths) ?? [])
        default: self = .other(type: type, parameters: try c.decodeIfPresent(JSONValue.self, forKey: .parameters))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        func keyed() -> KeyedEncodingContainer<ParameterKeys> { c.nestedContainer(keyedBy: ParameterKeys.self, forKey: .parameters) }
        switch self {
        case .creation, .deletion, .requiredLinearHistory, .requiredSignatures, .nonFastForward, .licenseComplianceScanning: break
        case .update(let allows):
            var p = keyed()
            try p.encode(allows, forKey: .updateAllowsFetchAndMerge)
        case .requiredDeployments(let environments):
            var p = keyed()
            try p.encode(environments, forKey: .requiredDeploymentEnvironments)
        case .pullRequest(let rule): try c.encode(rule, forKey: .parameters)
        case .requiredStatusChecks(let rule): try c.encode(rule, forKey: .parameters)
        case .mergeQueue(let rule): try c.encode(rule, forKey: .parameters)
        case .commitMessagePattern(let rule), .commitAuthorEmailPattern(let rule), .committerEmailPattern(let rule),
            .branchNamePattern(let rule), .tagNamePattern(let rule):
            try c.encode(rule, forKey: .parameters)
        case .workflows(let rule): try c.encode(rule, forKey: .parameters)
        case .codeScanning(let tools):
            var p = keyed()
            try p.encode(tools, forKey: .codeScanningTools)
        case .codeQuality(let severity):
            var p = keyed()
            try p.encode(severity, forKey: .severity)
        case .codeCoverage(let rule): try c.encode(rule, forKey: .parameters)
        case .copilotCodeReview(let rule): try c.encode(rule, forKey: .parameters)
        case .filePathRestriction(let restricted, let ignored):
            var p = keyed()
            try p.encode(restricted, forKey: .restrictedFilePaths)
            if !ignored.isEmpty { try p.encode(ignored, forKey: .ignoredFilePaths) }
        case .maxFilePathLength(let length):
            var p = keyed()
            try p.encode(length, forKey: .maxFilePathLength)
        case .fileExtensionRestriction(let extensions):
            var p = keyed()
            try p.encode(extensions, forKey: .restrictedFileExtensions)
        case .maxFileSize(let megabytes, let ignored):
            var p = keyed()
            try p.encode(megabytes, forKey: .maxFileSize)
            if !ignored.isEmpty { try p.encode(ignored, forKey: .ignoredFilePaths) }
        case .other(_, let parameters): try c.encodeIfPresent(parameters, forKey: .parameters)
        }
    }
}

/// A rule as it applies to a branch, with the ruleset it comes from (`repository-rule-detailed`).
public struct AppliedRule: Sendable, Hashable, Codable {
    public var rule: RepositoryRule
    public var rulesetID: Int?
    /// The repository (`owner/name`) or organization that owns the ruleset.
    public var rulesetSource: String?
    /// `Repository` or `Organization`.
    public var rulesetSourceType: String?

    enum CodingKeys: String, CodingKey {
        case rulesetID = "ruleset_id"
        case rulesetSource = "ruleset_source"
        case rulesetSourceType = "ruleset_source_type"
    }

    public init(from decoder: any Decoder) throws {
        rule = try RepositoryRule(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rulesetID = try c.decodeIfPresent(Int.self, forKey: .rulesetID)
        rulesetSource = try c.decodeIfPresent(String.self, forKey: .rulesetSource)
        rulesetSourceType = try c.decodeIfPresent(String.self, forKey: .rulesetSourceType)
    }

    public func encode(to encoder: any Encoder) throws {
        try rule.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(rulesetID, forKey: .rulesetID)
        try c.encodeIfPresent(rulesetSource, forKey: .rulesetSource)
        try c.encodeIfPresent(rulesetSourceType, forKey: .rulesetSourceType)
    }
}

/// Pull request requirements for a ruleset.
public struct PullRequestRule: Sendable, Hashable, Codable {
    /// From 0 to 10.
    public var requiredApprovingReviewCount: Int
    public var dismissStaleReviewsOnPush: Bool
    public var requireCodeOwnerReview: Bool
    /// Whether someone other than the last pusher must approve.
    public var requireLastPushApproval: Bool
    /// Whether every review thread must be resolved.
    public var requiredReviewThreadResolution: Bool
    /// At least one of `merge`, `squash`, and `rebase`.
    public var allowedMergeMethods: [String]?
    /// Who can dismiss reviews, when restricted.
    public var dismissalRestriction: DismissalRestriction?
    /// Requires one more approval when Copilot opens a pull request with no human collaborator.
    public var requireExtraApprovalForUnattributedChanges: Bool?
    /// Teams that must approve changes to matching files.
    public var requiredReviewers: [RequiredReviewer]?

    public init(
        requiredApprovingReviewCount: Int = 1, dismissStaleReviewsOnPush: Bool = false, requireCodeOwnerReview: Bool = false,
        requireLastPushApproval: Bool = false, requiredReviewThreadResolution: Bool = false, allowedMergeMethods: [String]? = nil,
        dismissalRestriction: DismissalRestriction? = nil, requireExtraApprovalForUnattributedChanges: Bool? = nil,
        requiredReviewers: [RequiredReviewer]? = nil
    ) {
        self.requiredApprovingReviewCount = requiredApprovingReviewCount
        self.dismissStaleReviewsOnPush = dismissStaleReviewsOnPush
        self.requireCodeOwnerReview = requireCodeOwnerReview
        self.requireLastPushApproval = requireLastPushApproval
        self.requiredReviewThreadResolution = requiredReviewThreadResolution
        self.allowedMergeMethods = allowedMergeMethods
        self.dismissalRestriction = dismissalRestriction
        self.requireExtraApprovalForUnattributedChanges = requireExtraApprovalForUnattributedChanges
        self.requiredReviewers = requiredReviewers
    }

    /// Who can dismiss pull request reviews.
    public struct DismissalRestriction: Sendable, Hashable, Codable {
        public var enabled: Bool
        public var allowedActors: [Actor]?

        public init(enabled: Bool = true, allowedActors: [Actor]? = nil) {
            self.enabled = enabled
            self.allowedActors = allowedActors
        }

        /// A user, team, app installation, or repository role.
        public struct Actor: Sendable, Hashable, Codable {
            public var id: Int
            /// `User`, `Team`, `IntegrationInstallation`, or `RepositoryRole`.
            public var type: String

            public init(id: Int, type: String) {
                self.id = id
                self.type = type
            }
        }

        enum CodingKeys: String, CodingKey {
            case enabled
            case allowedActors = "allowed_actors"
        }
    }

    /// A team that must approve changes to some files.
    public struct RequiredReviewer: Sendable, Hashable, Codable {
        /// Patterns in `fnmatch` syntax, such as `docs/**`.
        public var filePatterns: [String]
        /// With 0, the team is requested but its approval isn't required.
        public var minimumApprovals: Int
        public var reviewer: Reviewer

        public init(teamID: Int, filePatterns: [String], minimumApprovals: Int = 1) {
            self.filePatterns = filePatterns
            self.minimumApprovals = minimumApprovals
            self.reviewer = Reviewer(id: teamID, type: "Team")
        }

        /// The reviewer. Only teams are supported.
        public struct Reviewer: Sendable, Hashable, Codable {
            public var id: Int
            public var type: String
        }

        enum CodingKeys: String, CodingKey {
            case reviewer
            case filePatterns = "file_patterns"
            case minimumApprovals = "minimum_approvals"
        }
    }

    enum CodingKeys: String, CodingKey {
        case requiredApprovingReviewCount = "required_approving_review_count"
        case dismissStaleReviewsOnPush = "dismiss_stale_reviews_on_push"
        case requireCodeOwnerReview = "require_code_owner_review"
        case requireLastPushApproval = "require_last_push_approval"
        case requiredReviewThreadResolution = "required_review_thread_resolution"
        case allowedMergeMethods = "allowed_merge_methods"
        case dismissalRestriction = "dismissal_restriction"
        case requireExtraApprovalForUnattributedChanges = "require_extra_approval_for_unattributed_changes"
        case requiredReviewers = "required_reviewers"
    }
}

/// Status checks a ruleset requires.
public struct StatusChecksRule: Sendable, Hashable, Codable {
    public var requiredStatusChecks: [Check]
    /// Whether branches must be up to date with the base before merging.
    public var strictRequiredStatusChecksPolicy: Bool
    /// Lets a branch be created even when its checks would fail.
    public var doNotEnforceOnCreate: Bool?

    public init(_ checks: [Check], strict: Bool = false, doNotEnforceOnCreate: Bool? = nil) {
        self.requiredStatusChecks = checks
        self.strictRequiredStatusChecksPolicy = strict
        self.doNotEnforceOnCreate = doNotEnforceOnCreate
    }

    /// A required check, and optionally the app that must report it.
    public struct Check: Sendable, Hashable, Codable {
        public var context: String
        public var integrationID: Int?

        public init(_ context: String, integrationID: Int? = nil) {
            self.context = context
            self.integrationID = integrationID
        }

        enum CodingKeys: String, CodingKey {
            case context
            case integrationID = "integration_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case requiredStatusChecks = "required_status_checks"
        case strictRequiredStatusChecksPolicy = "strict_required_status_checks_policy"
        case doNotEnforceOnCreate = "do_not_enforce_on_create"
    }
}

/// Merge queue settings. The defaults match GitHub's.
public struct MergeQueueRule: Sendable, Hashable, Codable {
    /// How long a required check can take to report, from 1 to 360 minutes.
    public var checkResponseTimeoutMinutes: Int
    /// `ALLGREEN` (every pull request in a group must pass) or `HEADGREEN` (only the last one).
    public var groupingStrategy: String
    public var maxEntriesToBuild: Int
    public var maxEntriesToMerge: Int
    /// `MERGE`, `SQUASH`, or `REBASE`.
    public var mergeMethod: String
    public var minEntriesToMerge: Int
    public var minEntriesToMergeWaitMinutes: Int

    public init(
        checkResponseTimeoutMinutes: Int = 60, groupingStrategy: String = "ALLGREEN", maxEntriesToBuild: Int = 5,
        maxEntriesToMerge: Int = 5, mergeMethod: String = "MERGE", minEntriesToMerge: Int = 1, minEntriesToMergeWaitMinutes: Int = 5
    ) {
        self.checkResponseTimeoutMinutes = checkResponseTimeoutMinutes
        self.groupingStrategy = groupingStrategy
        self.maxEntriesToBuild = maxEntriesToBuild
        self.maxEntriesToMerge = maxEntriesToMerge
        self.mergeMethod = mergeMethod
        self.minEntriesToMerge = minEntriesToMerge
        self.minEntriesToMergeWaitMinutes = minEntriesToMergeWaitMinutes
    }

    enum CodingKeys: String, CodingKey {
        case checkResponseTimeoutMinutes = "check_response_timeout_minutes"
        case groupingStrategy = "grouping_strategy"
        case maxEntriesToBuild = "max_entries_to_build"
        case maxEntriesToMerge = "max_entries_to_merge"
        case mergeMethod = "merge_method"
        case minEntriesToMerge = "min_entries_to_merge"
        case minEntriesToMergeWaitMinutes = "min_entries_to_merge_wait_minutes"
    }
}

/// A text pattern that commit messages, emails, or ref names must match.
public struct PatternRule: Sendable, Hashable, Codable {
    public var `operator`: PatternOperator
    public var pattern: String
    /// Fails when the pattern matches, instead of when it doesn't.
    public var negate: Bool?
    /// How the rule appears in settings.
    public var name: String?

    public init(_ operator: PatternOperator, _ pattern: String, negate: Bool? = nil, name: String? = nil) {
        self.operator = `operator`
        self.pattern = pattern
        self.negate = negate
        self.name = name
    }
}

/// How a ``PatternRule`` matches.
public struct PatternOperator: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let startsWith: Self = "starts_with"
    public static let endsWith: Self = "ends_with"
    public static let contains: Self = "contains"
    public static let regex: Self = "regex"
}

/// Workflows that must pass before a ref updates.
public struct WorkflowsRule: Sendable, Hashable, Codable {
    public var workflows: [Workflow]
    /// Lets a branch be created even when its workflows would fail.
    public var doNotEnforceOnCreate: Bool?

    public init(_ workflows: [Workflow], doNotEnforceOnCreate: Bool? = nil) {
        self.workflows = workflows
        self.doNotEnforceOnCreate = doNotEnforceOnCreate
    }

    /// A workflow file in a repository.
    public struct Workflow: Sendable, Hashable, Codable {
        /// Such as `.github/workflows/ci.yml`.
        public var path: String
        public var repositoryID: Int
        /// A branch or tag. Pass this or ``sha``.
        public var ref: String?
        public var sha: String?

        public init(path: String, repositoryID: Int, ref: String? = nil, sha: String? = nil) {
            self.path = path
            self.repositoryID = repositoryID
            self.ref = ref
            self.sha = sha
        }

        enum CodingKeys: String, CodingKey {
            case path, ref, sha
            case repositoryID = "repository_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case workflows
        case doNotEnforceOnCreate = "do_not_enforce_on_create"
    }
}

/// A code scanning tool whose results can block a ref update.
public struct CodeScanningTool: Sendable, Hashable, Codable {
    /// Such as `CodeQL`.
    public var tool: String
    /// `none`, `errors`, `errors_and_warnings`, or `all`.
    public var alertsThreshold: String
    /// `none`, `critical`, `high_or_higher`, `medium_or_higher`, or `all`.
    public var securityAlertsThreshold: String

    public init(_ tool: String, alertsThreshold: String = "errors", securityAlertsThreshold: String = "high_or_higher") {
        self.tool = tool
        self.alertsThreshold = alertsThreshold
        self.securityAlertsThreshold = securityAlertsThreshold
    }

    enum CodingKeys: String, CodingKey {
        case tool
        case alertsThreshold = "alerts_threshold"
        case securityAlertsThreshold = "security_alerts_threshold"
    }
}

/// Code coverage limits.
public struct CodeCoverageRule: Sendable, Hashable, Codable {
    /// The most coverage may drop, in percentage points.
    public var maxCoverageDrop: Double?
    /// The lowest coverage allowed, as a percentage.
    public var minimumCoverage: Double?

    public init(maxCoverageDrop: Double? = nil, minimumCoverage: Double? = nil) {
        self.maxCoverageDrop = maxCoverageDrop
        self.minimumCoverage = minimumCoverage
    }

    enum CodingKeys: String, CodingKey {
        case maxCoverageDrop = "max_coverage_drop"
        case minimumCoverage = "minimum_coverage"
    }
}

/// When Copilot reviews pull requests.
public struct CopilotReviewRule: Sendable, Hashable, Codable {
    public var reviewDraftPullRequests: Bool?
    /// Reviews again on each push.
    public var reviewOnPush: Bool?

    public init(reviewDraftPullRequests: Bool? = nil, reviewOnPush: Bool? = nil) {
        self.reviewDraftPullRequests = reviewDraftPullRequests
        self.reviewOnPush = reviewOnPush
    }

    enum CodingKeys: String, CodingKey {
        case reviewDraftPullRequests = "review_draft_pull_requests"
        case reviewOnPush = "review_on_push"
    }
}

// MARK: - Inputs

/// A new ruleset.
public struct NewRuleset: Sendable, Hashable, Encodable {
    public var name: String
    public var enforcement: RulesetEnforcement
    /// Defaults to `branch`.
    public var target: RulesetTarget?
    public var bypassActors: [BypassActor]?
    public var conditions: RulesetConditions?
    public var rules: [RepositoryRule]?

    public init(
        name: String, enforcement: RulesetEnforcement = .active, target: RulesetTarget? = nil, bypassActors: [BypassActor]? = nil,
        conditions: RulesetConditions? = nil, rules: [RepositoryRule]? = nil
    ) {
        self.name = name
        self.enforcement = enforcement
        self.target = target
        self.bypassActors = bypassActors
        self.conditions = conditions
        self.rules = rules
    }

    enum CodingKeys: String, CodingKey {
        case name, enforcement, target, conditions, rules
        case bypassActors = "bypass_actors"
    }
}

/// Changes to a ruleset. Values you leave `nil` keep their current value; arrays you set replace the old ones.
public struct RulesetUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var enforcement: RulesetEnforcement?
    public var target: RulesetTarget?
    public var bypassActors: [BypassActor]?
    public var conditions: RulesetConditions?
    public var rules: [RepositoryRule]?

    public init(
        name: String? = nil, enforcement: RulesetEnforcement? = nil, target: RulesetTarget? = nil, bypassActors: [BypassActor]? = nil,
        conditions: RulesetConditions? = nil, rules: [RepositoryRule]? = nil
    ) {
        self.name = name
        self.enforcement = enforcement
        self.target = target
        self.bypassActors = bypassActors
        self.conditions = conditions
        self.rules = rules
    }

    enum CodingKeys: String, CodingKey {
        case name, enforcement, target, conditions, rules
        case bypassActors = "bypass_actors"
    }
}

// MARK: - History and insights

/// One saved version of a ruleset (`ruleset-version`, `ruleset-version-with-state`).
public struct RulesetVersion: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var actor: Actor?
    public var updatedAt: Date
    /// The ruleset as it was. Only included when fetching one version.
    public var state: Ruleset?

    /// Who saved the version.
    public struct Actor: Sendable, Hashable, Codable {
        public var id: Int?
        /// Such as `User`.
        public var type: String?
    }

    enum CodingKeys: String, CodingKey {
        case actor, state
        case id = "version_id"
        case updatedAt = "updated_at"
    }
}

/// The rules evaluated for one push (`rule-suite`).
public struct RuleSuite: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var actorID: Int?
    public var actorName: String?
    public var beforeSHA: String?
    public var afterSHA: String?
    public var ref: String?
    public var repositoryID: Int?
    public var repositoryName: String?
    public var pushedAt: Date?
    /// The outcome of the active rules: `pass`, `fail`, or `bypass`.
    public var result: String?
    /// The outcome if rules in evaluate mode had been active.
    public var evaluationResult: String?
    /// Only included when fetching one rule suite.
    public var ruleEvaluations: [RuleEvaluation]?

    enum CodingKeys: String, CodingKey {
        case id, ref, result
        case actorID = "actor_id"
        case actorName = "actor_name"
        case beforeSHA = "before_sha"
        case afterSHA = "after_sha"
        case repositoryID = "repository_id"
        case repositoryName = "repository_name"
        case pushedAt = "pushed_at"
        case evaluationResult = "evaluation_result"
        case ruleEvaluations = "rule_evaluations"
    }
}

/// How one rule judged a push.
public struct RuleEvaluation: Sendable, Hashable, Codable {
    public var ruleSource: Source?
    /// `active`, `evaluate`, or `deleted ruleset`.
    public var enforcement: String?
    /// `pass` or `fail`.
    public var result: String?
    /// Such as `pull_request`.
    public var ruleType: String?
    /// Why the rule failed.
    public var details: String?
    /// Extra data for pull request and status check rules, when requested.
    public var metadata: JSONValue?

    /// Where the rule came from.
    public struct Source: Sendable, Hashable, Codable {
        /// Such as `ruleset` or `protected_branch`.
        public var type: String?
        public var id: Int?
        public var name: String?
    }

    enum CodingKeys: String, CodingKey {
        case enforcement, result, details, metadata
        case ruleSource = "rule_source"
        case ruleType = "rule_type"
    }
}

/// How far back to look for rule suites.
public enum RuleSuitePeriod: String, Sendable, Hashable, CustomStringConvertible {
    case hour, day, week, month
    public var description: String { rawValue }
}

/// Narrows rule suites by outcome.
public enum RuleSuiteResultFilter: String, Sendable, Hashable, CustomStringConvertible {
    case all, pass, fail, bypass
    public var description: String { rawValue }
}

/// Narrows rule suites by enforcement.
public enum RuleSuiteEvaluateStatus: String, Sendable, Hashable, CustomStringConvertible {
    case all, active, evaluate
    public var description: String { rawValue }
}
