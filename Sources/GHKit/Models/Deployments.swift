import Foundation

/// A request to deploy a ref to an environment (`deployment`).
public struct Deployment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var sha: String
    public var ref: String
    /// Such as `deploy` or `deploy:migrations`.
    public var task: String
    public var environment: String
    /// The environment the deployment was first created for.
    public var originalEnvironment: String?
    public var description: String?
    public var creator: SimpleUser?
    /// Extra data for deployment tools: a JSON object or a string.
    public var payload: JSONValue?
    /// Whether the environment goes away later, such as a review app.
    public var isTransientEnvironment: Bool?
    /// Whether end users use the environment directly.
    public var isProductionEnvironment: Bool?
    /// The app that created the deployment, if any.
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL
    public var statusesURL: URL
    public var repositoryURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, sha, ref, task, environment, description, creator, payload, url
        case nodeID = "node_id"
        case originalEnvironment = "original_environment"
        case isTransientEnvironment = "transient_environment"
        case isProductionEnvironment = "production_environment"
        case performedViaGitHubApp = "performed_via_github_app"
        case statusesURL = "statuses_url"
        case repositoryURL = "repository_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// The progress of a deployment.
public struct DeploymentState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let queued: Self = "queued"
    public static let pending: Self = "pending"
    public static let inProgress: Self = "in_progress"
    public static let success: Self = "success"
    public static let failure: Self = "failure"
    public static let error: Self = "error"
    /// Replaced by a later deployment.
    public static let inactive: Self = "inactive"
}

/// One update on a deployment's progress (`deployment-status`).
public struct DeploymentStatus: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var state: DeploymentState
    public var creator: SimpleUser?
    public var description: String?
    public var environment: String?
    /// The deployment's output.
    public var logURL: URL?
    /// Where to use the deployed environment.
    public var environmentURL: URL?
    /// Replaced by ``logURL``.
    public var targetURL: URL?
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL
    public var deploymentURL: URL
    public var repositoryURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, state, creator, description, environment, url
        case nodeID = "node_id"
        case logURL = "log_url"
        case environmentURL = "environment_url"
        case targetURL = "target_url"
        case performedViaGitHubApp = "performed_via_github_app"
        case deploymentURL = "deployment_url"
        case repositoryURL = "repository_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nodeID = try c.decode(String.self, forKey: .nodeID)
        state = try c.decode(DeploymentState.self, forKey: .state)
        creator = try c.decodeIfPresent(SimpleUser.self, forKey: .creator)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        environment = try c.decodeIfPresent(String.self, forKey: .environment)
        // GitHub sends "" for URLs that weren't set.
        logURL = try c.decodeIfPresent(String.self, forKey: .logURL).flatMap(URL.init(string:))
        environmentURL = try c.decodeIfPresent(String.self, forKey: .environmentURL).flatMap(URL.init(string:))
        targetURL = try c.decodeIfPresent(String.self, forKey: .targetURL).flatMap(URL.init(string:))
        performedViaGitHubApp = try c.decodeIfPresent(GitHubApp.self, forKey: .performedViaGitHubApp)
        url = try c.decode(URL.self, forKey: .url)
        deploymentURL = try c.decode(URL.self, forKey: .deploymentURL)
        repositoryURL = try c.decode(URL.self, forKey: .repositoryURL)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

/// A deployment target such as `staging` or `production` (`environment`).
///
/// Named so it doesn't clash with SwiftUI's `Environment`.
public struct DeploymentEnvironment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var protectionRules: [EnvironmentProtectionRule]?
    /// Which refs can deploy. `nil` means any branch.
    public var deploymentBranchPolicy: DeploymentBranchPolicy?
    public var url: URL
    public var htmlURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case nodeID = "node_id"
        case protectionRules = "protection_rules"
        case deploymentBranchPolicy = "deployment_branch_policy"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A built-in rule an environment applies before deploying.
public struct EnvironmentProtectionRule: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    /// `wait_timer`, `required_reviewers`, or `branch_policy`.
    public var type: String
    /// Minutes to wait, for `wait_timer` rules.
    public var waitTimer: Int?
    /// Whether whoever started a deployment can't approve it, for `required_reviewers` rules.
    public var preventSelfReview: Bool?
    /// Who can approve, for `required_reviewers` rules.
    public var reviewers: [DeploymentReviewer]?

    enum CodingKeys: String, CodingKey {
        case id, type, reviewers
        case nodeID = "node_id"
        case waitTimer = "wait_timer"
        case preventSelfReview = "prevent_self_review"
    }
}

/// A person or team who can approve deployments.
public enum DeploymentReviewer: Sendable, Hashable, Codable {
    case user(SimpleUser)
    case team(Team)

    enum CodingKeys: String, CodingKey { case type, reviewer }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "Team": self = .team(try c.decode(Team.self, forKey: .reviewer))
        default: self = .user(try c.decode(SimpleUser.self, forKey: .reviewer))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user(let user):
            try c.encode("User", forKey: .type)
            try c.encode(user, forKey: .reviewer)
        case .team(let team):
            try c.encode("Team", forKey: .type)
            try c.encode(team, forKey: .reviewer)
        }
    }
}

/// Which refs can deploy to an environment (`deployment-branch-policy-settings`).
public enum DeploymentBranchPolicy: Sendable, Hashable, Codable {
    /// Any branch.
    case allBranches
    /// Only branches with branch protection.
    case protectedBranches
    /// Only refs matching the environment's ``DeploymentBranchPattern``s.
    case customPatterns

    enum CodingKeys: String, CodingKey {
        case protectedBranches = "protected_branches"
        case customBranchPolicies = "custom_branch_policies"
    }

    public init(from decoder: any Decoder) throws {
        if try decoder.singleValueContainer().decodeNil() {
            self = .allBranches
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if try c.decodeIfPresent(Bool.self, forKey: .protectedBranches) == true {
            self = .protectedBranches
        } else if try c.decodeIfPresent(Bool.self, forKey: .customBranchPolicies) == true {
            self = .customPatterns
        } else {
            self = .allBranches
        }
    }

    public func encode(to encoder: any Encoder) throws {
        guard self != .allBranches else {
            var single = encoder.singleValueContainer()
            try single.encodeNil()
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self == .protectedBranches, forKey: .protectedBranches)
        try c.encode(self == .customPatterns, forKey: .customBranchPolicies)
    }
}

/// A name pattern that branches or tags must match to deploy to an environment (`deployment-branch-policy`).
public struct DeploymentBranchPattern: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    /// A pattern such as `release/*`. Wildcards don't match `/`, so use `release/*/*` for deeper names.
    public var name: String
    public var type: DeploymentRefType?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case nodeID = "node_id"
    }
}

/// Whether a ``DeploymentBranchPattern`` matches branches or tags.
public struct DeploymentRefType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let branch: Self = "branch"
    public static let tag: Self = "tag"
}

/// A GitHub App that approves or rejects deployments to an environment (`deployment-protection-rule`).
public struct DeploymentProtectionRule: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var enabled: Bool
    public var app: ProtectionRuleApp

    enum CodingKeys: String, CodingKey {
        case id, enabled, app
        case nodeID = "node_id"
    }
}

/// An app that can act as a deployment protection rule (`custom-deployment-rule-app`).
public struct ProtectionRuleApp: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var slug: String
    public var integrationURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, slug
        case nodeID = "node_id"
        case integrationURL = "integration_url"
    }
}

// MARK: - Inputs

/// A new deployment.
public struct NewDeployment: Sendable, Hashable, Encodable {
    /// A branch, tag, or SHA.
    public var ref: String
    /// Defaults to `deploy`.
    public var task: String?
    /// Defaults to `production`.
    public var environment: String?
    public var description: String?
    /// Merges the default branch into `ref` first if it's behind. Defaults to `true`.
    public var autoMerge: Bool?
    /// Status contexts that must pass first. `[]` skips the check; `nil` requires every context.
    public var requiredContexts: [String]?
    /// Extra data for deployment tools.
    public var payload: JSONValue?
    public var isTransientEnvironment: Bool?
    public var isProductionEnvironment: Bool?

    public init(
        ref: String, task: String? = nil, environment: String? = nil, description: String? = nil, autoMerge: Bool? = nil,
        requiredContexts: [String]? = nil, payload: JSONValue? = nil, isTransientEnvironment: Bool? = nil,
        isProductionEnvironment: Bool? = nil
    ) {
        self.ref = ref
        self.task = task
        self.environment = environment
        self.description = description
        self.autoMerge = autoMerge
        self.requiredContexts = requiredContexts
        self.payload = payload
        self.isTransientEnvironment = isTransientEnvironment
        self.isProductionEnvironment = isProductionEnvironment
    }

    enum CodingKeys: String, CodingKey {
        case ref, task, environment, description, payload
        case autoMerge = "auto_merge"
        case requiredContexts = "required_contexts"
        case isTransientEnvironment = "transient_environment"
        case isProductionEnvironment = "production_environment"
    }
}

/// A progress update for a deployment.
public struct NewDeploymentStatus: Sendable, Hashable, Encodable {
    public var state: DeploymentState
    /// The deployment's output.
    public var logURL: URL?
    /// Where to use the deployed environment.
    public var environmentURL: URL?
    /// Up to 140 characters.
    public var description: String?
    /// Moves the deployment to another environment.
    public var environment: String?
    /// Marks earlier deployments to the same environment `inactive` when this one succeeds. Defaults to `true`.
    public var autoInactive: Bool?

    public init(
        _ state: DeploymentState, logURL: URL? = nil, environmentURL: URL? = nil, description: String? = nil, environment: String? = nil,
        autoInactive: Bool? = nil
    ) {
        self.state = state
        self.logURL = logURL
        self.environmentURL = environmentURL
        self.description = description
        self.environment = environment
        self.autoInactive = autoInactive
    }

    enum CodingKeys: String, CodingKey {
        case state, description, environment
        case logURL = "log_url"
        case environmentURL = "environment_url"
        case autoInactive = "auto_inactive"
    }
}

/// Protection settings for an environment. Values you leave `nil` keep their current value.
public struct EnvironmentSettings: Sendable, Hashable, Encodable {
    /// Minutes to wait before deploying, up to 43,200 (30 days).
    public var waitTimer: Int?
    /// Stops whoever started a deployment from approving it.
    public var preventSelfReview: Bool?
    /// Up to six people or teams; any one of them can approve. `[]` removes the requirement.
    public var reviewers: [Reviewer]?
    public var deploymentBranchPolicy: DeploymentBranchPolicy?

    public init(
        waitTimer: Int? = nil, preventSelfReview: Bool? = nil, reviewers: [Reviewer]? = nil,
        deploymentBranchPolicy: DeploymentBranchPolicy? = nil
    ) {
        self.waitTimer = waitTimer
        self.preventSelfReview = preventSelfReview
        self.reviewers = reviewers
        self.deploymentBranchPolicy = deploymentBranchPolicy
    }

    /// A reviewer, by ID.
    public struct Reviewer: Sendable, Hashable, Encodable {
        public var type: String
        public var id: Int

        public static func user(_ id: Int) -> Self { Self(type: "User", id: id) }
        public static func team(_ id: Int) -> Self { Self(type: "Team", id: id) }
    }

    enum CodingKeys: String, CodingKey {
        case reviewers
        case waitTimer = "wait_timer"
        case preventSelfReview = "prevent_self_review"
        case deploymentBranchPolicy = "deployment_branch_policy"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(waitTimer, forKey: .waitTimer)
        try c.encodeIfPresent(preventSelfReview, forKey: .preventSelfReview)
        try c.encodeIfPresent(reviewers, forKey: .reviewers)
        // `.allBranches` encodes as an explicit null, which GitHub needs to lift a policy.
        if let deploymentBranchPolicy { try c.encode(deploymentBranchPolicy, forKey: .deploymentBranchPolicy) }
    }
}
