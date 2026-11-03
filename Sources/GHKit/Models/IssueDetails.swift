import Foundation

// MARK: - Events

/// What happened in an issue event, such as `labeled` or `closed`.
public struct IssueEventType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let closed: Self = "closed"
    public static let reopened: Self = "reopened"
    public static let merged: Self = "merged"
    /// A commit mentioned the issue.
    public static let referenced: Self = "referenced"
    public static let mentioned: Self = "mentioned"
    public static let subscribed: Self = "subscribed"
    public static let unsubscribed: Self = "unsubscribed"
    public static let labeled: Self = "labeled"
    public static let unlabeled: Self = "unlabeled"
    public static let assigned: Self = "assigned"
    public static let unassigned: Self = "unassigned"
    public static let milestoned: Self = "milestoned"
    public static let demilestoned: Self = "demilestoned"
    public static let renamed: Self = "renamed"
    public static let locked: Self = "locked"
    public static let unlocked: Self = "unlocked"
    public static let reviewRequested: Self = "review_requested"
    public static let reviewRequestRemoved: Self = "review_request_removed"
    public static let reviewDismissed: Self = "review_dismissed"
    public static let headRefDeleted: Self = "head_ref_deleted"
    public static let headRefRestored: Self = "head_ref_restored"
    public static let headRefForcePushed: Self = "head_ref_force_pushed"
    public static let convertedToDraft: Self = "convert_to_draft"
    public static let readyForReview: Self = "ready_for_review"
    public static let transferred: Self = "transferred"
    public static let pinned: Self = "pinned"
    public static let unpinned: Self = "unpinned"
    public static let markedAsDuplicate: Self = "marked_as_duplicate"
    public static let unmarkedAsDuplicate: Self = "unmarked_as_duplicate"
    public static let issueTypeAdded: Self = "issue_type_added"
    public static let issueTypeRemoved: Self = "issue_type_removed"
    public static let issueTypeChanged: Self = "issue_type_changed"
    public static let subIssueAdded: Self = "sub_issue_added"
    public static let subIssueRemoved: Self = "sub_issue_removed"
    public static let parentIssueAdded: Self = "parent_issue_added"
    public static let parentIssueRemoved: Self = "parent_issue_removed"
    public static let blockedByAdded: Self = "blocked_by_added"
    public static let blockedByRemoved: Self = "blocked_by_removed"
    public static let blockingAdded: Self = "blocking_added"
    public static let blockingRemoved: Self = "blocking_removed"
}

/// How sure an automated suggestion or event was.
public struct SuggestionConfidence: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let low: Self = "LOW"
    public static let medium: Self = "MEDIUM"
    public static let high: Self = "HIGH"
}

/// Something that happened to an issue or pull request, such as a label added or a reviewer requested
/// (`issue-event`, `issue-event-for-issue`).
///
/// Which optional fields are set depends on ``event``.
public struct IssueEvent: Sendable, Hashable, Codable, Identifiable {
    /// A label added or removed.
    public struct Label: Sendable, Hashable, Codable {
        public var name: String?
        public var color: String?
    }

    /// A review that was dismissed.
    public struct DismissedReview: Sendable, Hashable, Codable {
        public var state: String
        public var reviewID: Int
        public var message: String?
        public var commitID: String?

        enum CodingKeys: String, CodingKey {
            case state
            case reviewID = "review_id"
            case message = "dismissal_message"
            case commitID = "dismissal_commit_id"
        }
    }

    /// A title change.
    public struct Rename: Sendable, Hashable, Codable {
        public var from: String
        public var to: String
    }

    /// An issue type added, removed, or replaced.
    public struct TypeReference: Sendable, Hashable, Codable {
        public var id: Int
        public var name: String
        public var color: IssueTypeColor?
    }

    /// Why an automated actor made the change.
    public struct Intent: Sendable, Hashable, Codable {
        public var rationale: String?
        public var confidence: SuggestionConfidence?
    }

    public var id: Int
    public var nodeID: String
    public var event: IssueEventType
    public var actor: SimpleUser?
    /// The commit that caused the event, such as a commit that closed the issue.
    public var commitID: String?
    public var commitURL: URL?
    /// The issue, in a repository-wide event list.
    public var issue: GitHubIssue?
    public var label: Label?
    public var assignee: SimpleUser?
    public var assigner: SimpleUser?
    public var reviewRequester: SimpleUser?
    public var requestedReviewer: SimpleUser?
    public var requestedTeam: Team?
    public var dismissedReview: DismissedReview?
    /// The milestone's title.
    public var milestoneTitle: String?
    public var rename: Rename?
    public var issueType: TypeReference?
    public var previousIssueType: TypeReference?
    public var subIssue: IssueReference?
    public var parentIssue: IssueReference?
    public var blockedBy: IssueReference?
    public var blocking: IssueReference?
    public var intent: Intent?
    public var lockReason: LockReason?
    public var stateReason: IssueStateReason?
    public var authorAssociation: AuthorAssociation?
    public var performedViaGitHubApp: GitHubApp?
    public var url: URL?
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, event, actor, issue, label, assignee, assigner, milestone, rename, intent, url
        case nodeID = "node_id"
        case commitID = "commit_id"
        case commitURL = "commit_url"
        case reviewRequester = "review_requester"
        case requestedReviewer = "requested_reviewer"
        case requestedTeam = "requested_team"
        case dismissedReview = "dismissed_review"
        case issueType = "issue_type"
        case previousIssueType = "prev_issue_type"
        case subIssue = "sub_issue"
        case parentIssue = "parent_issue"
        case blockedBy = "blocked_by"
        case blocking
        case lockReason = "lock_reason"
        case stateReason = "state_reason"
        case authorAssociation = "author_association"
        case performedViaGitHubApp = "performed_via_github_app"
        case createdAt = "created_at"
    }

    private struct MilestoneReference: Codable { var title: String }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        nodeID = try c.decode(String.self, forKey: .nodeID)
        event = try c.decode(IssueEventType.self, forKey: .event)
        actor = try c.decodeIfPresent(SimpleUser.self, forKey: .actor)
        commitID = try c.decodeIfPresent(String.self, forKey: .commitID)
        commitURL = try c.decodeIfPresent(URL.self, forKey: .commitURL)
        issue = try c.decodeIfPresent(GitHubIssue.self, forKey: .issue)
        label = try c.decodeIfPresent(Label.self, forKey: .label)
        assignee = try c.decodeIfPresent(SimpleUser.self, forKey: .assignee)
        assigner = try c.decodeIfPresent(SimpleUser.self, forKey: .assigner)
        reviewRequester = try c.decodeIfPresent(SimpleUser.self, forKey: .reviewRequester)
        requestedReviewer = try c.decodeIfPresent(SimpleUser.self, forKey: .requestedReviewer)
        requestedTeam = try c.decodeIfPresent(Team.self, forKey: .requestedTeam)
        dismissedReview = try c.decodeIfPresent(DismissedReview.self, forKey: .dismissedReview)
        milestoneTitle = try c.decodeIfPresent(MilestoneReference.self, forKey: .milestone)?.title
        rename = try c.decodeIfPresent(Rename.self, forKey: .rename)
        issueType = try c.decodeIfPresent(TypeReference.self, forKey: .issueType)
        previousIssueType = try c.decodeIfPresent(TypeReference.self, forKey: .previousIssueType)
        subIssue = try c.decodeIfPresent(IssueReference.self, forKey: .subIssue)
        parentIssue = try c.decodeIfPresent(IssueReference.self, forKey: .parentIssue)
        blockedBy = try c.decodeIfPresent(IssueReference.self, forKey: .blockedBy)
        blocking = try c.decodeIfPresent(IssueReference.self, forKey: .blocking)
        intent = try c.decodeIfPresent(Intent.self, forKey: .intent)
        lockReason = try c.decodeIfPresent(LockReason.self, forKey: .lockReason)
        stateReason = try c.decodeIfPresent(IssueStateReason.self, forKey: .stateReason)
        authorAssociation = try c.decodeIfPresent(AuthorAssociation.self, forKey: .authorAssociation)
        performedViaGitHubApp = try c.decodeIfPresent(GitHubApp.self, forKey: .performedViaGitHubApp)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nodeID, forKey: .nodeID)
        try c.encode(event, forKey: .event)
        try c.encodeIfPresent(actor, forKey: .actor)
        try c.encodeIfPresent(commitID, forKey: .commitID)
        try c.encodeIfPresent(commitURL, forKey: .commitURL)
        try c.encodeIfPresent(issue, forKey: .issue)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(assignee, forKey: .assignee)
        try c.encodeIfPresent(assigner, forKey: .assigner)
        try c.encodeIfPresent(reviewRequester, forKey: .reviewRequester)
        try c.encodeIfPresent(requestedReviewer, forKey: .requestedReviewer)
        try c.encodeIfPresent(requestedTeam, forKey: .requestedTeam)
        try c.encodeIfPresent(dismissedReview, forKey: .dismissedReview)
        try c.encodeIfPresent(milestoneTitle.map(MilestoneReference.init), forKey: .milestone)
        try c.encodeIfPresent(rename, forKey: .rename)
        try c.encodeIfPresent(issueType, forKey: .issueType)
        try c.encodeIfPresent(previousIssueType, forKey: .previousIssueType)
        try c.encodeIfPresent(subIssue, forKey: .subIssue)
        try c.encodeIfPresent(parentIssue, forKey: .parentIssue)
        try c.encodeIfPresent(blockedBy, forKey: .blockedBy)
        try c.encodeIfPresent(blocking, forKey: .blocking)
        try c.encodeIfPresent(intent, forKey: .intent)
        try c.encodeIfPresent(lockReason, forKey: .lockReason)
        try c.encodeIfPresent(stateReason, forKey: .stateReason)
        try c.encodeIfPresent(authorAssociation, forKey: .authorAssociation)
        try c.encodeIfPresent(performedViaGitHubApp, forKey: .performedViaGitHubApp)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

/// A short reference to an issue from an event, such as the sub-issue that was added.
public struct IssueReference: Sendable, Hashable, Codable {
    /// The referenced issue's type.
    public struct TypeReference: Sendable, Hashable, Codable {
        public var id: Int
        public var nodeID: String
        public var name: String
        public var color: IssueTypeColor?

        enum CodingKeys: String, CodingKey {
            case id, name, color
            case nodeID = "node_id"
        }
    }

    public var number: Int
    public var title: String
    public var state: IssueState
    public var stateReason: IssueStateReason?
    public var repository: Repository
    public var issueType: TypeReference?

    enum CodingKeys: String, CodingKey {
        case number, title, state, repository
        case stateReason = "state_reason"
        case issueType = "issue_type"
    }
}

/// Where to move a sub-issue among its siblings.
public enum SubIssuePosition: Sendable, Hashable {
    /// Right after the sub-issue with this ``GitHubIssue/id``.
    case after(Int)
    /// Right before the sub-issue with this ``GitHubIssue/id``.
    case before(Int)
}

// MARK: - Issue fields

/// The kind of value an issue field holds.
public struct IssueFieldDataType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let text: Self = "text"
    public static let number: Self = "number"
    public static let date: Self = "date"
    public static let singleSelect: Self = "single_select"
    public static let multiSelect: Self = "multi_select"
}

/// Who can see an issue field's values.
public struct IssueFieldVisibility: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let organizationMembersOnly: Self = "organization_members_only"
    /// Everyone who can see the issue.
    public static let all: Self = "all"
}

/// A custom field an organization adds to its issues, such as Priority (`issue-field`).
public struct IssueField: Sendable, Hashable, Codable, Identifiable {
    /// A choice in a single- or multi-select field.
    public struct Option: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var name: String
        public var description: String?
        public var color: IssueTypeColor?
        /// Lower numbers sort first.
        public var priority: Int?
        public var createdAt: Date?
        public var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, description, color, priority
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    public var id: Int
    public var nodeID: String
    public var name: String
    public var description: String?
    public var dataType: IssueFieldDataType
    public var visibility: IssueFieldVisibility?
    public var options: [Option]?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, visibility, options
        case nodeID = "node_id"
        case dataType = "data_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A choice to create or keep in a select field.
public struct IssueFieldOptionInput: Sendable, Hashable, Encodable {
    /// An existing option's ID, to keep or change it. `nil` creates an option.
    public var id: Int?
    public var name: String
    public var description: String?
    public var color: IssueTypeColor
    /// Lower numbers sort first.
    public var priority: Int

    public init(id: Int? = nil, name: String, description: String? = nil, color: IssueTypeColor, priority: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.color = color
        self.priority = priority
    }
}

/// An issue field to create.
public struct NewIssueField: Sendable, Hashable, Encodable {
    public var name: String
    public var description: String?
    public var dataType: IssueFieldDataType
    public var visibility: IssueFieldVisibility?
    /// Required for select fields.
    public var options: [IssueFieldOptionInput]?

    public init(
        name: String, description: String? = nil, dataType: IssueFieldDataType, visibility: IssueFieldVisibility? = nil,
        options: [IssueFieldOptionInput]? = nil
    ) {
        self.name = name
        self.description = description
        self.dataType = dataType
        self.visibility = visibility
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case name, description, visibility, options
        case dataType = "data_type"
    }
}

/// Changes to an issue field. `nil` leaves a field as it is.
public struct IssueFieldUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var description: String?
    public var visibility: IssueFieldVisibility?
    /// Replaces every option. Include an existing option's `id` to keep it.
    public var options: [IssueFieldOptionInput]?

    public init(
        name: String? = nil, description: String? = nil, visibility: IssueFieldVisibility? = nil,
        options: [IssueFieldOptionInput]? = nil
    ) {
        self.name = name
        self.description = description
        self.visibility = visibility
        self.options = options
    }
}

/// An issue field's value on one issue (`issue-field-value`).
public struct IssueFieldValue: Sendable, Hashable, Codable {
    /// A chosen option in a select field.
    public struct Option: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var name: String
        public var color: String?
    }

    public var fieldID: Int
    public var fieldName: String?
    public var nodeID: String
    public var dataType: IssueFieldDataType
    /// Text, a number, or a date string, depending on ``dataType``.
    public var value: JSONValue
    public var singleSelectOption: Option?
    public var multiSelectOptions: [Option]?

    enum CodingKeys: String, CodingKey {
        case value
        case fieldID = "issue_field_id"
        case fieldName = "issue_field_name"
        case nodeID = "node_id"
        case dataType = "data_type"
        case singleSelectOption = "single_select_option"
        case multiSelectOptions = "multi_select_options"
    }
}

/// A value to give an issue field on an issue.
public struct NewIssueFieldValue: Sendable, Hashable, Encodable {
    /// What to store.
    public enum Value: Sendable, Hashable, Encodable {
        /// Text, a date (`YYYY-MM-DD`), or a single-select option's name.
        case text(String)
        case number(Double)
        /// Multi-select option names.
        case options([String])

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .text(let text): try c.encode(text)
            case .number(let number): try c.encode(number)
            case .options(let names): try c.encode(names)
            }
        }
    }

    public var fieldID: Int
    public var value: Value

    public init(fieldID: Int, value: Value) {
        self.fieldID = fieldID
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case value
        case fieldID = "field_id"
    }
}

// MARK: - Issue types

/// An issue type to create, or the new settings for one.
public struct IssueTypeInput: Sendable, Hashable, Encodable {
    public var name: String
    /// Disabled types can't be given to new issues.
    public var isEnabled: Bool
    public var description: String?
    public var color: IssueTypeColor?

    public init(name: String, isEnabled: Bool = true, description: String? = nil, color: IssueTypeColor? = nil) {
        self.name = name
        self.isEnabled = isEnabled
        self.description = description
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case name, description, color
        case isEnabled = "is_enabled"
    }
}

// MARK: - Suggestions

/// What an issue suggestion would do.
public struct IssueSuggestionAction: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let setType: Self = "set_type"
    public static let addLabel: Self = "add_label"
    public static let addField: Self = "add_field"
    public static let addAssignee: Self = "add_assignee"
    public static let closeIssue: Self = "close_issue"
}

/// Where an issue suggestion stands.
public struct IssueSuggestionState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending: Self = "pending"
    public static let approved: Self = "approved"
    public static let applied: Self = "applied"
    public static let dismissed: Self = "dismissed"
    /// A newer suggestion took its place.
    public static let replaced: Self = "replaced"
    /// The issue changed so the suggestion no longer applies.
    public static let invalidated: Self = "invalidated"
}

/// A change GitHub suggests for an issue, such as a label or a type, waiting for someone to approve it
/// (`issue-suggestion`).
public struct IssueSuggestion: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var issueID: Int
    public var action: IssueSuggestionAction
    public var state: IssueSuggestionState
    /// The label, type, field, or user the suggestion points at.
    public var targetID: Int?
    /// The suggested value, such as a type name.
    public var targetValue: JSONValue?
    public var rationale: String?
    public var confidence: SuggestionConfidence?
    public var actorID: Int?
    /// The event recorded when the suggestion was applied.
    public var issueEventID: Int?
    /// The user ID of whoever approved or dismissed it.
    public var resolvedBy: Int?
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action, state, rationale, confidence
        case issueID = "issue_id"
        case targetID = "target_id"
        case targetValue = "target_value"
        case actorID = "actor_id"
        case issueEventID = "issue_event_id"
        case resolvedBy = "resolved_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Artifacts

/// The kind of content an issue artifact holds.
public struct IssueArtifactType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let generic: Self = "generic"
    public static let link: Self = "link"
    public static let plan: Self = "plan"
    public static let embeddedHTML: Self = "embedded_html"
}

/// A document attached to an issue, such as an implementation plan (`issue-artifact`).
public struct IssueArtifact: Sendable, Hashable, Codable, Identifiable {
    /// Who created or last changed an artifact.
    public struct Actor: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var login: String
    }

    /// An earlier version of an artifact.
    public struct Version: Sendable, Hashable, Codable {
        public var version: Int
        public var name: String
        public var body: String
        public var bodyHTML: String?
        public var actor: Actor?
        public var createdAt: Date?

        enum CodingKeys: String, CodingKey {
            case version, name, body, actor
            case bodyHTML = "body_html"
            case createdAt = "created_at"
        }
    }

    public var id: Int
    /// The artifact's number within its issue.
    public var number: Int
    public var type: IssueArtifactType
    public var name: String
    /// Markdown.
    public var body: String
    /// `nil` if rendering took too long.
    public var bodyHTML: String?
    public var description: String
    public var creator: Actor
    public var updatedBy: Actor
    public var htmlURL: URL?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, number, type, name, body, description, creator
        case bodyHTML = "body_html"
        case updatedBy = "updated_by_actor"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// An artifact and its earlier versions, newest first.
public struct IssueArtifactHistory: Sendable, Hashable, Codable {
    public var artifact: IssueArtifact
    public var versions: [IssueArtifact.Version]

    enum CodingKeys: String, CodingKey { case artifact, versions }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.artifact) {
            artifact = try c.decode(IssueArtifact.self, forKey: .artifact)
            versions = try c.decodeIfPresent([IssueArtifact.Version].self, forKey: .versions) ?? []
        } else {
            artifact = try IssueArtifact(from: decoder)
            versions = []
        }
    }
}

/// An artifact to attach to an issue.
public struct NewIssueArtifact: Sendable, Hashable, Encodable {
    public var name: String
    /// Markdown.
    public var body: String
    public var type: IssueArtifactType?

    public init(name: String, body: String, type: IssueArtifactType? = nil) {
        self.name = name
        self.body = body
        self.type = type
    }
}
