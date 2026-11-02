import Foundation

/// A branch in a list (`short-branch`).
public struct Branch: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var commit: GitCommit.Pointer
    public var isProtected: Bool
    /// A summary of the branch's protection. Fetch ``BranchProtection`` for the full rules.
    public var protection: BranchProtection?
    public var protectionURL: URL?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, commit, protection
        case isProtected = "protected"
        case protectionURL = "protection_url"
    }
}

/// A branch with its head commit and protection (`branch-with-protection`).
public struct BranchDetails: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var commit: Commit
    public var isProtected: Bool
    public var protection: BranchProtection?
    public var protectionURL: URL?
    public var htmlURL: URL?
    /// The branch protection pattern that matched this branch, such as `release/*`.
    public var pattern: String?
    public var requiredApprovingReviewCount: Int?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, commit, protection, pattern
        case isProtected = "protected"
        case protectionURL = "protection_url"
        case links = "_links"
        case requiredApprovingReviewCount = "required_approving_review_count"
    }

    enum LinkKeys: String, CodingKey { case html }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        commit = try c.decode(Commit.self, forKey: .commit)
        isProtected = try c.decode(Bool.self, forKey: .isProtected)
        protection = try c.decodeIfPresent(BranchProtection.self, forKey: .protection)
        protectionURL = try c.decodeIfPresent(URL.self, forKey: .protectionURL)
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
        requiredApprovingReviewCount = try c.decodeIfPresent(Int.self, forKey: .requiredApprovingReviewCount)
        htmlURL = try c.contains(.links) ? c.nestedContainer(keyedBy: LinkKeys.self, forKey: .links).decodeIfPresent(URL.self, forKey: .html) : nil
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(commit, forKey: .commit)
        try c.encode(isProtected, forKey: .isProtected)
        try c.encodeIfPresent(protection, forKey: .protection)
        try c.encodeIfPresent(protectionURL, forKey: .protectionURL)
        try c.encodeIfPresent(pattern, forKey: .pattern)
        try c.encodeIfPresent(requiredApprovingReviewCount, forKey: .requiredApprovingReviewCount)
        if let htmlURL {
            var links = c.nestedContainer(keyedBy: LinkKeys.self, forKey: .links)
            try links.encode(htmlURL, forKey: .html)
        }
    }
}

/// The rules protecting a branch (`branch-protection`, `protected-branch`).
///
/// GitHub reports each simple rule as `{"enabled": true}`. They're exposed here as plain `Bool?` values.
public struct BranchProtection: Sendable, Hashable, Codable {
    public var url: URL?
    public var name: String?
    public var enabled: Bool?
    public var requiredStatusChecks: StatusCheckPolicy?
    public var requiredPullRequestReviews: ReviewProtection?
    /// Who can push. `nil` means anyone with write access.
    public var restrictions: BranchRestrictions?
    public var enforceAdmins: Bool?
    public var requiredSignatures: Bool?
    public var requiredLinearHistory: Bool?
    public var allowForcePushes: Bool?
    public var allowDeletions: Bool?
    public var blockCreations: Bool?
    public var requiredConversationResolution: Bool?
    /// Whether the branch is read-only.
    public var lockBranch: Bool?
    /// Whether a locked branch can still sync from upstream.
    public var allowForkSyncing: Bool?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case url, name, enabled, restrictions
        case requiredStatusChecks = "required_status_checks"
        case requiredPullRequestReviews = "required_pull_request_reviews"
        case enforceAdmins = "enforce_admins"
        case requiredSignatures = "required_signatures"
        case requiredLinearHistory = "required_linear_history"
        case allowForcePushes = "allow_force_pushes"
        case allowDeletions = "allow_deletions"
        case blockCreations = "block_creations"
        case requiredConversationResolution = "required_conversation_resolution"
        case lockBranch = "lock_branch"
        case allowForkSyncing = "allow_fork_syncing"
    }

    private struct Toggle: Codable { var enabled: Bool? }

    private var toggles: [(WritableKeyPath<Self, Bool?>, CodingKeys)] {
        [
            (\.enforceAdmins, .enforceAdmins), (\.requiredSignatures, .requiredSignatures),
            (\.requiredLinearHistory, .requiredLinearHistory), (\.allowForcePushes, .allowForcePushes),
            (\.allowDeletions, .allowDeletions), (\.blockCreations, .blockCreations),
            (\.requiredConversationResolution, .requiredConversationResolution), (\.lockBranch, .lockBranch),
            (\.allowForkSyncing, .allowForkSyncing),
        ]
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        requiredStatusChecks = try c.decodeIfPresent(StatusCheckPolicy.self, forKey: .requiredStatusChecks)
        requiredPullRequestReviews = try c.decodeIfPresent(ReviewProtection.self, forKey: .requiredPullRequestReviews)
        restrictions = try c.decodeIfPresent(BranchRestrictions.self, forKey: .restrictions)
        for (keyPath, key) in toggles {
            self[keyPath: keyPath] = try c.decodeIfPresent(Toggle.self, forKey: key)?.enabled
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(enabled, forKey: .enabled)
        try c.encodeIfPresent(requiredStatusChecks, forKey: .requiredStatusChecks)
        try c.encodeIfPresent(requiredPullRequestReviews, forKey: .requiredPullRequestReviews)
        try c.encodeIfPresent(restrictions, forKey: .restrictions)
        for (keyPath, key) in toggles {
            if let value = self[keyPath: keyPath] { try c.encode(Toggle(enabled: value), forKey: key) }
        }
    }
}

/// The status checks that must pass before merging (`status-check-policy`).
public struct StatusCheckPolicy: Sendable, Hashable, Codable {
    public var url: URL?
    /// Whether branches must be up to date with the base before merging.
    public var strict: Bool?
    /// The required check names. Prefer ``checks``, which also names the app that must report each one.
    public var contexts: [String]
    public var checks: [StatusCheck]
    public var contextsURL: URL?
    /// Such as `non_admins` or `everyone`.
    public var enforcementLevel: String?

    enum CodingKeys: String, CodingKey {
        case url, strict, contexts, checks
        case contextsURL = "contexts_url"
        case enforcementLevel = "enforcement_level"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        strict = try c.decodeIfPresent(Bool.self, forKey: .strict)
        contexts = try c.decodeIfPresent([String].self, forKey: .contexts) ?? []
        checks = try c.decodeIfPresent([StatusCheck].self, forKey: .checks) ?? []
        contextsURL = try c.decodeIfPresent(URL.self, forKey: .contextsURL)
        enforcementLevel = try c.decodeIfPresent(String.self, forKey: .enforcementLevel)
    }
}

/// A required status check, and optionally the GitHub App that must report it.
public struct StatusCheck: Sendable, Hashable, Codable {
    /// The check's name, such as `ci/build`.
    public var context: String
    /// The app that must report the check. `nil` picks the app that last reported it; ``anyApp`` accepts any source.
    public var appID: Int?

    /// Accepts the check from any app or status.
    public static let anyApp = -1

    public init(_ context: String, appID: Int? = nil) {
        self.context = context
        self.appID = appID
    }

    enum CodingKeys: String, CodingKey {
        case context
        case appID = "app_id"
    }
}

/// Pull request review rules for a protected branch (`protected-branch-pull-request-review`).
public struct ReviewProtection: Sendable, Hashable, Codable {
    public var url: URL?
    /// Who can dismiss reviews. `nil` means anyone with write access.
    public var dismissalRestrictions: BranchActors?
    /// Who can merge without meeting the review rules.
    public var bypassPullRequestAllowances: BranchActors?
    public var dismissStaleReviews: Bool?
    public var requireCodeOwnerReviews: Bool?
    /// From 0 to 6.
    public var requiredApprovingReviewCount: Int?
    /// Whether someone other than the last pusher must approve.
    public var requireLastPushApproval: Bool?

    enum CodingKeys: String, CodingKey {
        case url
        case dismissalRestrictions = "dismissal_restrictions"
        case bypassPullRequestAllowances = "bypass_pull_request_allowances"
        case dismissStaleReviews = "dismiss_stale_reviews"
        case requireCodeOwnerReviews = "require_code_owner_reviews"
        case requiredApprovingReviewCount = "required_approving_review_count"
        case requireLastPushApproval = "require_last_push_approval"
    }
}

/// People, teams, and apps a branch rule applies to.
public struct BranchActors: Sendable, Hashable, Codable {
    public var users: [SimpleUser]
    public var teams: [Team]
    public var apps: [GitHubApp]

    enum CodingKeys: String, CodingKey { case users, teams, apps }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        users = try c.decodeIfPresent([SimpleUser].self, forKey: .users) ?? []
        teams = try c.decodeIfPresent([Team].self, forKey: .teams) ?? []
        apps = try c.decodeIfPresent([GitHubApp].self, forKey: .apps) ?? []
    }
}

/// Who can push to a protected branch (`branch-restriction-policy`).
public struct BranchRestrictions: Sendable, Hashable, Codable {
    public var url: URL?
    public var users: [SimpleUser]
    public var teams: [Team]
    public var apps: [GitHubApp]

    enum CodingKeys: String, CodingKey { case url, users, teams, apps }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        users = try c.decodeIfPresent([SimpleUser].self, forKey: .users) ?? []
        teams = try c.decodeIfPresent([Team].self, forKey: .teams) ?? []
        apps = try c.decodeIfPresent([GitHubApp].self, forKey: .apps) ?? []
    }
}

// MARK: - Inputs

/// The full set of rules to apply to a branch with ``RepositoriesAPI/protect(_:in:_:rules:)``.
///
/// GitHub replaces every rule at once, so a `nil` rule turns that rule off.
public struct BranchProtectionRules: Sendable, Hashable, Encodable {
    public var requiredStatusChecks: RequiredStatusChecks?
    public var requiredPullRequestReviews: RequiredReviews?
    /// Who can push. `nil` lets anyone with write access push. Only for organization repositories.
    public var restrictions: PushAllowances?
    /// Whether the rules also bind administrators.
    public var enforceAdmins: Bool
    public var requiredLinearHistory: Bool?
    public var allowForcePushes: Bool?
    public var allowDeletions: Bool?
    /// Stops anyone outside ``restrictions`` creating matching branches.
    public var blockCreations: Bool?
    public var requiredConversationResolution: Bool?
    public var lockBranch: Bool?
    public var allowForkSyncing: Bool?

    public init(
        requiredStatusChecks: RequiredStatusChecks? = nil, requiredPullRequestReviews: RequiredReviews? = nil,
        restrictions: PushAllowances? = nil, enforceAdmins: Bool = false, requiredLinearHistory: Bool? = nil,
        allowForcePushes: Bool? = nil, allowDeletions: Bool? = nil, blockCreations: Bool? = nil,
        requiredConversationResolution: Bool? = nil, lockBranch: Bool? = nil, allowForkSyncing: Bool? = nil
    ) {
        self.requiredStatusChecks = requiredStatusChecks
        self.requiredPullRequestReviews = requiredPullRequestReviews
        self.restrictions = restrictions
        self.enforceAdmins = enforceAdmins
        self.requiredLinearHistory = requiredLinearHistory
        self.allowForcePushes = allowForcePushes
        self.allowDeletions = allowDeletions
        self.blockCreations = blockCreations
        self.requiredConversationResolution = requiredConversationResolution
        self.lockBranch = lockBranch
        self.allowForkSyncing = allowForkSyncing
    }

    enum CodingKeys: String, CodingKey {
        case restrictions
        case requiredStatusChecks = "required_status_checks"
        case requiredPullRequestReviews = "required_pull_request_reviews"
        case enforceAdmins = "enforce_admins"
        case requiredLinearHistory = "required_linear_history"
        case allowForcePushes = "allow_force_pushes"
        case allowDeletions = "allow_deletions"
        case blockCreations = "block_creations"
        case requiredConversationResolution = "required_conversation_resolution"
        case lockBranch = "lock_branch"
        case allowForkSyncing = "allow_fork_syncing"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // GitHub requires these four keys, with `null` to turn a rule off.
        try c.encode(requiredStatusChecks, forKey: .requiredStatusChecks)
        try c.encode(requiredPullRequestReviews, forKey: .requiredPullRequestReviews)
        try c.encode(restrictions, forKey: .restrictions)
        try c.encode(enforceAdmins, forKey: .enforceAdmins)
        try c.encodeIfPresent(requiredLinearHistory, forKey: .requiredLinearHistory)
        try c.encodeIfPresent(allowForcePushes, forKey: .allowForcePushes)
        try c.encodeIfPresent(allowDeletions, forKey: .allowDeletions)
        try c.encodeIfPresent(blockCreations, forKey: .blockCreations)
        try c.encodeIfPresent(requiredConversationResolution, forKey: .requiredConversationResolution)
        try c.encodeIfPresent(lockBranch, forKey: .lockBranch)
        try c.encodeIfPresent(allowForkSyncing, forKey: .allowForkSyncing)
    }
}

/// Status checks to require before merging.
public struct RequiredStatusChecks: Sendable, Hashable, Encodable {
    /// Whether branches must be up to date with the base before merging.
    public var strict: Bool
    public var checks: [StatusCheck]

    public init(strict: Bool = false, checks: [StatusCheck]) {
        self.strict = strict
        self.checks = checks
    }

}

/// Review rules to require before merging. Also used by ``RepositoriesAPI/updateReviewProtection(_:on:in:_:)``.
public struct RequiredReviews: Sendable, Hashable, Encodable {
    /// Who can dismiss reviews. Pass an empty value to let anyone with write access dismiss them.
    public var dismissalRestrictions: PushAllowances?
    /// Who can merge without meeting the review rules.
    public var bypassPullRequestAllowances: PushAllowances?
    public var dismissStaleReviews: Bool?
    public var requireCodeOwnerReviews: Bool?
    /// From 0 to 6.
    public var requiredApprovingReviewCount: Int?
    public var requireLastPushApproval: Bool?

    public init(
        requiredApprovingReviewCount: Int? = 1, dismissStaleReviews: Bool? = nil, requireCodeOwnerReviews: Bool? = nil,
        requireLastPushApproval: Bool? = nil, dismissalRestrictions: PushAllowances? = nil,
        bypassPullRequestAllowances: PushAllowances? = nil
    ) {
        self.requiredApprovingReviewCount = requiredApprovingReviewCount
        self.dismissStaleReviews = dismissStaleReviews
        self.requireCodeOwnerReviews = requireCodeOwnerReviews
        self.requireLastPushApproval = requireLastPushApproval
        self.dismissalRestrictions = dismissalRestrictions
        self.bypassPullRequestAllowances = bypassPullRequestAllowances
    }

    enum CodingKeys: String, CodingKey {
        case dismissalRestrictions = "dismissal_restrictions"
        case bypassPullRequestAllowances = "bypass_pull_request_allowances"
        case dismissStaleReviews = "dismiss_stale_reviews"
        case requireCodeOwnerReviews = "require_code_owner_reviews"
        case requiredApprovingReviewCount = "required_approving_review_count"
        case requireLastPushApproval = "require_last_push_approval"
    }
}

/// Users, teams, and apps named by login and slug.
public struct PushAllowances: Sendable, Hashable, Encodable {
    /// User logins.
    public var users: [String]
    /// Team slugs.
    public var teams: [String]
    /// App slugs.
    public var apps: [String]

    public init(users: [String] = [], teams: [String] = [], apps: [String] = []) {
        self.users = users
        self.teams = teams
        self.apps = apps
    }
}
