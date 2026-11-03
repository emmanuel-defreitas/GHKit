import Foundation

/// Whether an issue or pull request is open or closed.
public struct IssueState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let open: Self = "open"
    public static let closed: Self = "closed"
}

/// Why an issue was closed or reopened.
public struct IssueStateReason: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let completed: Self = "completed"
    public static let notPlanned: Self = "not_planned"
    /// Closed as a duplicate of another issue.
    public static let duplicate: Self = "duplicate"
    public static let reopened: Self = "reopened"
}

/// Why a conversation was locked.
public struct LockReason: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let offTopic: Self = "off-topic"
    public static let tooHeated: Self = "too heated"
    public static let resolved: Self = "resolved"
    public static let spam: Self = "spam"
}

/// An issue (`issue`). Pull requests are issues too: ``pullRequest`` is set for them.
public struct GitHubIssue: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var number: Int
    public var title: String
    /// Markdown.
    public var body: String?
    public var state: IssueState
    public var stateReason: IssueStateReason?
    public var user: SimpleUser?
    public var labels: [IssueLabel]
    public var assignee: SimpleUser?
    public var assignees: [SimpleUser]?
    public var milestone: Milestone?
    public var type: IssueType?
    public var isLocked: Bool
    public var activeLockReason: LockReason?
    public var commentCount: Int
    /// Links to the pull request, or `nil` for a plain issue.
    public var pullRequest: IssuePullRequestLinks?
    public var isDraft: Bool?
    public var closedBy: SimpleUser?
    public var authorAssociation: AuthorAssociation?
    public var reactions: ReactionSummary?
    public var subIssuesSummary: SubIssuesSummary?
    public var dependenciesSummary: IssueDependenciesSummary?
    public var parentIssueURL: URL?
    public var pinnedComment: IssueComment?
    /// The repository, in lists that span several repositories.
    public var repository: Repository?
    /// The GitHub App that opened the issue for someone.
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL
    public var htmlURL: URL
    public var repositoryURL: URL
    public var timelineURL: URL?
    public var closedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    /// `true` for a pull request.
    public var isPullRequest: Bool { pullRequest != nil }

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, assignee, assignees, milestone, type, reactions, repository, url
        case nodeID = "node_id"
        case stateReason = "state_reason"
        case isLocked = "locked"
        case activeLockReason = "active_lock_reason"
        case commentCount = "comments"
        case pullRequest = "pull_request"
        case isDraft = "draft"
        case closedBy = "closed_by"
        case authorAssociation = "author_association"
        case subIssuesSummary = "sub_issues_summary"
        case dependenciesSummary = "issue_dependencies_summary"
        case parentIssueURL = "parent_issue_url"
        case pinnedComment = "pinned_comment"
        case performedViaGitHubApp = "performed_via_github_app"
        case htmlURL = "html_url"
        case repositoryURL = "repository_url"
        case timelineURL = "timeline_url"
        case closedAt = "closed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Links from an issue to the pull request it represents.
public struct IssuePullRequestLinks: Sendable, Hashable, Codable {
    public var url: URL?
    public var htmlURL: URL?
    public var diffURL: URL?
    public var patchURL: URL?
    /// `nil` until the pull request is merged.
    public var mergedAt: Date?

    enum CodingKeys: String, CodingKey {
        case url
        case htmlURL = "html_url"
        case diffURL = "diff_url"
        case patchURL = "patch_url"
        case mergedAt = "merged_at"
    }
}

/// Progress on an issue's sub-issues.
public struct SubIssuesSummary: Sendable, Hashable, Codable {
    public var total: Int
    public var completed: Int
    public var percentCompleted: Int

    enum CodingKeys: String, CodingKey {
        case total, completed
        case percentCompleted = "percent_completed"
    }
}

/// How many issues block an issue, and how many it blocks.
public struct IssueDependenciesSummary: Sendable, Hashable, Codable {
    /// Open issues blocking this one.
    public var blockedBy: Int
    /// Open issues this one blocks.
    public var blocking: Int
    public var totalBlockedBy: Int
    public var totalBlocking: Int

    enum CodingKeys: String, CodingKey {
        case blockedBy = "blocked_by"
        case blocking
        case totalBlockedBy = "total_blocked_by"
        case totalBlocking = "total_blocking"
    }
}

/// The color of an issue type.
public struct IssueTypeColor: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let gray: Self = "gray"
    public static let blue: Self = "blue"
    public static let green: Self = "green"
    public static let yellow: Self = "yellow"
    public static let orange: Self = "orange"
    public static let red: Self = "red"
    public static let pink: Self = "pink"
    public static let purple: Self = "purple"
}

/// An organization's kind of issue, such as Bug or Feature (`issue-type`).
public struct IssueType: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var description: String?
    public var color: IssueTypeColor?
    public var isEnabled: Bool?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, color
        case nodeID = "node_id"
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Comments

/// A comment on an issue or pull request conversation (`issue-comment`).
public struct IssueComment: Sendable, Hashable, Codable, Identifiable {
    /// Who pinned a comment, and when.
    public struct Pin: Sendable, Hashable, Codable {
        public var pinnedAt: Date
        public var pinnedBy: SimpleUser?

        enum CodingKeys: String, CodingKey {
            case pinnedAt = "pinned_at"
            case pinnedBy = "pinned_by"
        }
    }

    public var id: Int
    public var nodeID: String
    /// Markdown.
    public var body: String?
    public var user: SimpleUser?
    public var authorAssociation: AuthorAssociation?
    public var reactions: ReactionSummary?
    /// Set when the comment is pinned to the top of the conversation.
    public var pin: Pin?
    /// Why the comment was hidden, such as `spam` or `outdated`. `nil` when it's visible.
    public var minimizedReason: String?
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL
    public var htmlURL: URL
    public var issueURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user, reactions, pin, minimized, url
        case nodeID = "node_id"
        case authorAssociation = "author_association"
        case performedViaGitHubApp = "performed_via_github_app"
        case htmlURL = "html_url"
        case issueURL = "issue_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    private struct Minimized: Codable { var reason: String? }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nodeID = try c.decode(String.self, forKey: .nodeID)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        user = try c.decodeIfPresent(SimpleUser.self, forKey: .user)
        authorAssociation = try c.decodeIfPresent(AuthorAssociation.self, forKey: .authorAssociation)
        reactions = try c.decodeIfPresent(ReactionSummary.self, forKey: .reactions)
        pin = try c.decodeIfPresent(Pin.self, forKey: .pin)
        minimizedReason = try c.decodeIfPresent(Minimized.self, forKey: .minimized)?.reason
        performedViaGitHubApp = try c.decodeIfPresent(GitHubApp.self, forKey: .performedViaGitHubApp)
        url = try c.decode(URL.self, forKey: .url)
        htmlURL = try c.decode(URL.self, forKey: .htmlURL)
        issueURL = try c.decode(URL.self, forKey: .issueURL)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nodeID, forKey: .nodeID)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(user, forKey: .user)
        try c.encodeIfPresent(authorAssociation, forKey: .authorAssociation)
        try c.encodeIfPresent(reactions, forKey: .reactions)
        try c.encodeIfPresent(pin, forKey: .pin)
        try c.encodeIfPresent(minimizedReason.map { Minimized(reason: $0) }, forKey: .minimized)
        try c.encodeIfPresent(performedViaGitHubApp, forKey: .performedViaGitHubApp)
        try c.encode(url, forKey: .url)
        try c.encode(htmlURL, forKey: .htmlURL)
        try c.encode(issueURL, forKey: .issueURL)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

/// How to sort a repository's issue comments.
public enum IssueCommentSort: String, Sendable, Hashable, CustomStringConvertible {
    case created, updated
    public var description: String { rawValue }
}

// MARK: - Labels

/// A label on issues and pull requests (`label`).
///
/// Labels inside an ``GitHubIssue`` may carry only a name. Fetch the label for the rest.
public struct IssueLabel: Sendable, Hashable, Codable, Identifiable {
    public var id: Int?
    public var nodeID: String?
    public var name: String
    public var description: String?
    /// A hex color without the `#`, such as `f29513`.
    public var color: String?
    /// `true` for the labels every new repository starts with.
    public var isDefault: Bool?
    /// Set when the label is archived and can't be added to issues.
    public var archivedAt: Date?
    public var archivedBy: SimpleUser?
    public var url: URL?

    public init(name: String) {
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, color, url
        case nodeID = "node_id"
        case isDefault = "default"
        case archivedAt = "archived_at"
        case archivedBy = "archived_by"
    }

    public init(from decoder: any Decoder) throws {
        // Issues may list labels as bare names.
        if let name = try? decoder.singleValueContainer().decode(String.self) {
            self.init(name: name)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try c.decode(String.self, forKey: .name))
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        archivedBy = try c.decodeIfPresent(SimpleUser.self, forKey: .archivedBy)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
    }
}

/// A label to create.
public struct NewLabel: Sendable, Hashable, Encodable {
    /// Emoji are allowed, as text (`:strawberry:`) or as the character.
    public var name: String
    /// A hex color without the `#`, such as `f29513`.
    public var color: String?
    /// Up to 100 characters.
    public var description: String?

    public init(name: String, color: String? = nil, description: String? = nil) {
        self.name = name
        self.color = color
        self.description = description
    }
}

/// Changes to a label. `nil` leaves a field as it is.
public struct LabelUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var color: String?
    public var description: String?
    /// Archived labels stay on issues but can't be added to new ones.
    public var isArchived: Bool?

    public init(name: String? = nil, color: String? = nil, description: String? = nil, isArchived: Bool? = nil) {
        self.name = name
        self.color = color
        self.description = description
        self.isArchived = isArchived
    }

    enum CodingKeys: String, CodingKey {
        case color, description
        case name = "new_name"
        case isArchived = "archived"
    }
}

// MARK: - Milestones

/// A milestone that groups issues and pull requests (`milestone`).
public struct Milestone: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var number: Int
    public var title: String
    public var description: String?
    public var state: IssueState
    public var creator: SimpleUser?
    public var openIssues: Int
    public var closedIssues: Int
    public var dueOn: Date?
    public var url: URL
    public var htmlURL: URL
    public var createdAt: Date
    public var updatedAt: Date
    public var closedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, state, creator, url
        case nodeID = "node_id"
        case openIssues = "open_issues"
        case closedIssues = "closed_issues"
        case dueOn = "due_on"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
    }
}

/// How to sort milestones.
public enum MilestoneSort: String, Sendable, Hashable, CustomStringConvertible {
    case dueOn = "due_on"
    /// By the share of closed issues.
    case completeness
    public var description: String { rawValue }
}

/// A milestone to create.
public struct NewMilestone: Sendable, Hashable, Encodable {
    public var title: String
    public var state: IssueState?
    public var description: String?
    public var dueOn: Date?

    public init(title: String, state: IssueState? = nil, description: String? = nil, dueOn: Date? = nil) {
        self.title = title
        self.state = state
        self.description = description
        self.dueOn = dueOn
    }

    enum CodingKeys: String, CodingKey {
        case title, state, description
        case dueOn = "due_on"
    }
}

/// Changes to a milestone. `nil` leaves a field as it is.
public struct MilestoneUpdate: Sendable, Hashable, Encodable {
    public var title: String?
    public var state: IssueState?
    public var description: String?
    public var dueOn: Date?

    public init(title: String? = nil, state: IssueState? = nil, description: String? = nil, dueOn: Date? = nil) {
        self.title = title
        self.state = state
        self.description = description
        self.dueOn = dueOn
    }

    enum CodingKeys: String, CodingKey {
        case title, state, description
        case dueOn = "due_on"
    }
}
