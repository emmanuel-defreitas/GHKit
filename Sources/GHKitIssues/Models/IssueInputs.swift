import Foundation
import GHKitCore

/// An issue to open.
public struct NewIssue: Sendable, Hashable, Encodable {
    public var title: String
    /// Markdown.
    public var body: String?
    /// Logins to assign. Dropped without an error if you can't push to the repository.
    public var assignees: [String]
    /// The milestone's number. Dropped without an error if you can't push to the repository.
    public var milestone: Int?
    /// Label names. Dropped without an error if you can't push to the repository.
    public var labels: [String]
    /// The issue type's name, such as `Bug`.
    public var type: String?
    /// Opens the issue as a sub-issue of this issue. Takes the parent's ``GitHubIssue/id``, not its number.
    public var parentIssueID: Int?
    /// Values for the organization's issue fields.
    public var fieldValues: [NewIssueFieldValue]

    public init(
        title: String, body: String? = nil, assignees: [String] = [], milestone: Int? = nil, labels: [String] = [],
        type: String? = nil, parentIssueID: Int? = nil, fieldValues: [NewIssueFieldValue] = []
    ) {
        self.title = title
        self.body = body
        self.assignees = assignees
        self.milestone = milestone
        self.labels = labels
        self.type = type
        self.parentIssueID = parentIssueID
        self.fieldValues = fieldValues
    }

    enum CodingKeys: String, CodingKey {
        case title, body, assignees, milestone, labels, type
        case parentIssueID = "parent_issue_id"
        case fieldValues = "issue_field_values"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(body, forKey: .body)
        if !assignees.isEmpty { try c.encode(assignees, forKey: .assignees) }
        try c.encodeIfPresent(milestone, forKey: .milestone)
        if !labels.isEmpty { try c.encode(labels, forKey: .labels) }
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(parentIssueID, forKey: .parentIssueID)
        if !fieldValues.isEmpty { try c.encode(fieldValues, forKey: .fieldValues) }
    }
}

/// Changes to an issue. `nil` leaves a field as it is.
public struct IssueUpdate: Sendable, Hashable, Encodable {
    /// A value to set, or a request to remove it.
    public enum Change<Value: Sendable & Hashable>: Sendable, Hashable {
        case set(Value)
        case remove
    }

    public var title: String?
    /// Markdown. An empty string clears it.
    public var body: String?
    public var state: IssueState?
    public var stateReason: IssueStateReason?
    /// The ``GitHubIssue/id`` of the issue this one duplicates. Use with ``IssueStateReason/duplicate``.
    public var duplicateOf: Int?
    /// Replaces every assignee. An empty array removes them all.
    public var assignees: [String]?
    /// Replaces every label. An empty array removes them all.
    public var labels: [String]?
    /// A milestone number.
    public var milestone: Change<Int>?
    /// An issue type's name.
    public var type: Change<String>?
    /// Sets these issue field values. Fields left out keep their values.
    public var fieldValues: [NewIssueFieldValue]?

    public init(
        title: String? = nil, body: String? = nil, state: IssueState? = nil, stateReason: IssueStateReason? = nil,
        duplicateOf: Int? = nil, assignees: [String]? = nil, labels: [String]? = nil, milestone: Change<Int>? = nil,
        type: Change<String>? = nil, fieldValues: [NewIssueFieldValue]? = nil
    ) {
        self.title = title
        self.body = body
        self.state = state
        self.stateReason = stateReason
        self.duplicateOf = duplicateOf
        self.assignees = assignees
        self.labels = labels
        self.milestone = milestone
        self.type = type
        self.fieldValues = fieldValues
    }

    enum CodingKeys: String, CodingKey {
        case title, body, state, assignees, labels, milestone, type
        case stateReason = "state_reason"
        case duplicateOf = "duplicate_issue_id"
        case fieldValues = "issue_field_values"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(stateReason, forKey: .stateReason)
        try c.encodeIfPresent(duplicateOf, forKey: .duplicateOf)
        try c.encodeIfPresent(assignees, forKey: .assignees)
        try c.encodeIfPresent(labels, forKey: .labels)
        try c.encodeIfPresent(fieldValues, forKey: .fieldValues)
        switch milestone {
        case .set(let number)?: try c.encode(number, forKey: .milestone)
        case .remove?: try c.encodeNil(forKey: .milestone)
        case nil: break
        }
        switch type {
        case .set(let name)?: try c.encode(name, forKey: .type)
        case .remove?: try c.encodeNil(forKey: .type)
        case nil: break
        }
    }
}

// MARK: - Filters

/// How to sort issues.
public enum IssueSort: String, Sendable, Hashable, CustomStringConvertible {
    case created, updated
    /// By number of comments.
    case comments
    public var description: String { rawValue }
}

/// How the signed-in user relates to the issues to list.
public enum IssueRelationship: String, Sendable, Hashable, CustomStringConvertible {
    case assigned, created, mentioned, subscribed
    /// Every issue in repositories the user can see, whatever their part in it.
    case all
    /// Every issue in repositories the user watches.
    case watchedRepositories = "repos"
    public var description: String { rawValue }
}

/// Where to list the signed-in user's issues from.
public enum IssueScope: Sendable, Hashable {
    /// Every repository the user can see, including organization repositories. `GET /issues`
    case everywhere
    /// Repositories the user owns or is a member of. `GET /user/issues`
    case personalRepositories
    /// One organization's repositories. `GET /orgs/{org}/issues`
    case organization(String)
}

/// Narrows issue lists. Pull requests are included: check ``GitHubIssue/isPullRequest``.
public struct IssueFilter: Sendable, Hashable {
    /// Narrows issues by assignee.
    public enum Assignee: Sendable, Hashable {
        case user(String)
        case anyone
        case unassigned
    }

    /// Narrows issues by milestone.
    public enum MilestoneFilter: Sendable, Hashable {
        /// A milestone number.
        case number(Int)
        case any
        case noMilestone
    }

    public var state: IssueStateFilter
    /// Issues with every one of these labels.
    public var labels: [String]
    /// Only issues updated at or after this time.
    public var updatedSince: Date?
    /// An issue type's name, `*` for any type, or `none`. Repository and organization lists only.
    public var type: String?
    /// Repository lists only.
    public var milestone: MilestoneFilter?
    /// Repository lists only.
    public var assignee: Assignee?
    /// The author's login. Repository lists only.
    public var creator: String?
    /// A login mentioned in the issue. Repository lists only.
    public var mentioned: String?

    public init(
        state: IssueStateFilter = .open, labels: [String] = [], updatedSince: Date? = nil, type: String? = nil,
        milestone: MilestoneFilter? = nil, assignee: Assignee? = nil, creator: String? = nil, mentioned: String? = nil
    ) {
        self.state = state
        self.labels = labels
        self.updatedSince = updatedSince
        self.type = type
        self.milestone = milestone
        self.assignee = assignee
        self.creator = creator
        self.mentioned = mentioned
    }

    func query(repository: Bool, organization: Bool) -> [URLQueryItem] {
        var items: [URLQueryItem] = .query(
            ("state", state), ("labels", labels.isEmpty ? nil : labels.joined(separator: ",")),
            ("since", updatedSince?.ISO8601Format()))
        if repository || organization {
            items += .query(("type", type))
        }
        if repository {
            let milestone: String? =
                switch milestone {
                case .number(let number)?: String(number)
                case .any?: "*"
                case .noMilestone?: "none"
                case nil: nil
                }
            let assignee: String? =
                switch assignee {
                case .user(let login)?: login
                case .anyone?: "*"
                case .unassigned?: "none"
                case nil: nil
                }
            items += .query(("milestone", milestone), ("assignee", assignee), ("creator", creator), ("mentioned", mentioned))
        }
        return items
    }
}
