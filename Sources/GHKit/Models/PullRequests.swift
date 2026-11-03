import Foundation

/// How a pull request's commits land on the base branch.
public struct MergeMethod: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// A merge commit.
    public static let merge: Self = "merge"
    /// One commit with every change.
    public static let squash: Self = "squash"
    /// Each commit replayed onto the base branch.
    public static let rebase: Self = "rebase"
}

/// Whether GitHub can merge a pull request, and what's in the way.
public struct MergeableState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Ready to merge.
    public static let clean: Self = "clean"
    /// Merge conflicts.
    public static let dirty: Self = "dirty"
    /// Blocked by branch protection, such as a missing review.
    public static let blocked: Self = "blocked"
    /// The head branch is behind the base branch.
    public static let behind: Self = "behind"
    /// Mergeable, but some checks failed.
    public static let unstable: Self = "unstable"
    /// Mergeable, with pre-receive hooks passing.
    public static let hasHooks: Self = "has_hooks"
    public static let draft: Self = "draft"
    /// GitHub is still working it out. Fetch the pull request again in a moment.
    public static let unknown: Self = "unknown"
}

/// A pull request (`pull-request`, `pull-request-simple`).
///
/// Lists leave out the merge status and the counts. Fetch one pull request to get them.
public struct PullRequest: Sendable, Hashable, Codable, Identifiable {
    /// One side of a pull request: the branch to merge, or the branch it merges into.
    public struct Branch: Sendable, Hashable, Codable {
        /// `owner:branch`, such as `octocat:new-topic`.
        public var label: String?
        public var ref: String
        public var sha: String
        /// `nil` when the head repository was deleted.
        public var repository: Repository?
        public var user: SimpleUser?

        enum CodingKeys: String, CodingKey {
            case label, ref, sha, user
            case repository = "repo"
        }
    }

    /// Auto-merge settings, when someone turned it on.
    public struct AutoMerge: Sendable, Hashable, Codable {
        public var enabledBy: SimpleUser
        public var mergeMethod: MergeMethod
        public var commitTitle: String?
        public var commitMessage: String?

        enum CodingKeys: String, CodingKey {
            case enabledBy = "enabled_by"
            case mergeMethod = "merge_method"
            case commitTitle = "commit_title"
            case commitMessage = "commit_message"
        }
    }

    /// Where the pull request sits in a stack.
    public struct StackPosition: Sendable, Hashable, Codable {
        /// The bottom of the stack's base branch.
        public struct Base: Sendable, Hashable, Codable {
            public var ref: String
            public var sha: String?
        }

        public var id: Int?
        public var number: Int?
        public var base: Base
        public var size: Int?
        /// 1 is the bottom of the stack.
        public var position: Int?
    }

    public var id: Int
    public var nodeID: String
    public var number: Int
    public var title: String
    /// Markdown.
    public var body: String?
    public var state: IssueState
    public var isDraft: Bool?
    public var isLocked: Bool
    public var activeLockReason: LockReason?
    public var user: SimpleUser?
    public var labels: [IssueLabel]
    public var milestone: Milestone?
    public var assignee: SimpleUser?
    public var assignees: [SimpleUser]?
    public var requestedReviewers: [SimpleUser]?
    public var requestedTeams: [Team]?
    /// The branch with the changes.
    public var head: Branch
    /// The branch the changes merge into.
    public var base: Branch
    public var authorAssociation: AuthorAssociation?
    public var autoMerge: AutoMerge?
    public var stack: StackPosition?
    /// Only in a single pull request.
    public var isMerged: Bool?
    /// `nil` while GitHub works it out. Only in a single pull request.
    public var isMergeable: Bool?
    public var isRebaseable: Bool?
    public var mergeableState: MergeableState?
    public var mergedBy: SimpleUser?
    /// The merge commit, or for an open pull request, a test merge commit.
    public var mergeCommitSHA: String?
    public var maintainerCanModify: Bool?
    public var commentCount: Int?
    public var reviewCommentCount: Int?
    public var commitCount: Int?
    public var additions: Int?
    public var deletions: Int?
    public var changedFiles: Int?
    public var url: URL
    public var htmlURL: URL
    public var diffURL: URL?
    public var patchURL: URL?
    public var issueURL: URL?
    public var createdAt: Date
    public var updatedAt: Date
    public var closedAt: Date?
    public var mergedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, milestone, assignee, assignees, head, base, stack, additions,
            deletions, url
        case nodeID = "node_id"
        case isDraft = "draft"
        case isLocked = "locked"
        case activeLockReason = "active_lock_reason"
        case requestedReviewers = "requested_reviewers"
        case requestedTeams = "requested_teams"
        case authorAssociation = "author_association"
        case autoMerge = "auto_merge"
        case isMerged = "merged"
        case isMergeable = "mergeable"
        case isRebaseable = "rebaseable"
        case mergeableState = "mergeable_state"
        case mergedBy = "merged_by"
        case mergeCommitSHA = "merge_commit_sha"
        case maintainerCanModify = "maintainer_can_modify"
        case commentCount = "comments"
        case reviewCommentCount = "review_comments"
        case commitCount = "commits"
        case changedFiles = "changed_files"
        case htmlURL = "html_url"
        case diffURL = "diff_url"
        case patchURL = "patch_url"
        case issueURL = "issue_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case mergedAt = "merged_at"
    }
}

/// How to sort pull requests.
public enum PullRequestSort: String, Sendable, Hashable, CustomStringConvertible {
    case created, updated
    /// By number of comments.
    case popularity
    /// By age, for pull requests updated in the past month.
    case longRunning = "long-running"
    public var description: String { rawValue }
}

/// A pull request to open.
public struct NewPullRequest: Sendable, Hashable, Encodable {
    /// What to open the pull request from.
    public enum Source: Sendable, Hashable {
        /// A new pull request with this title.
        case title(String)
        /// Turns an existing issue, by number, into the pull request.
        case issue(Int)
    }

    public var source: Source
    /// The branch with the changes. From a fork, use `owner:branch`.
    public var head: String
    /// The branch to merge into.
    public var base: String
    /// The fork the head branch lives in, as `owner/name`, when it's in the same organization.
    public var headRepository: String?
    /// Markdown. Ignored when converting an issue.
    public var body: String?
    public var isDraft: Bool?
    /// Lets maintainers of the base repository push to the head branch.
    public var maintainerCanModify: Bool?

    public init(
        title: String, head: String, base: String, headRepository: String? = nil, body: String? = nil, isDraft: Bool? = nil,
        maintainerCanModify: Bool? = nil
    ) {
        self.init(
            source: .title(title), head: head, base: base, headRepository: headRepository, body: body, isDraft: isDraft,
            maintainerCanModify: maintainerCanModify)
    }

    public init(
        source: Source, head: String, base: String, headRepository: String? = nil, body: String? = nil, isDraft: Bool? = nil,
        maintainerCanModify: Bool? = nil
    ) {
        self.source = source
        self.head = head
        self.base = base
        self.headRepository = headRepository
        self.body = body
        self.isDraft = isDraft
        self.maintainerCanModify = maintainerCanModify
    }

    enum CodingKeys: String, CodingKey {
        case title, issue, head, base, body
        case headRepository = "head_repo"
        case isDraft = "draft"
        case maintainerCanModify = "maintainer_can_modify"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch source {
        case .title(let title): try c.encode(title, forKey: .title)
        case .issue(let number): try c.encode(number, forKey: .issue)
        }
        try c.encode(head, forKey: .head)
        try c.encode(base, forKey: .base)
        try c.encodeIfPresent(headRepository, forKey: .headRepository)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(isDraft, forKey: .isDraft)
        try c.encodeIfPresent(maintainerCanModify, forKey: .maintainerCanModify)
    }
}

/// Changes to a pull request. `nil` leaves a field as it is.
public struct PullRequestUpdate: Sendable, Hashable, Encodable {
    public var title: String?
    /// Markdown.
    public var body: String?
    public var state: IssueState?
    /// Retargets the pull request at another branch.
    public var base: String?
    public var maintainerCanModify: Bool?

    public init(
        title: String? = nil, body: String? = nil, state: IssueState? = nil, base: String? = nil, maintainerCanModify: Bool? = nil
    ) {
        self.title = title
        self.body = body
        self.state = state
        self.base = base
        self.maintainerCanModify = maintainerCanModify
    }

    enum CodingKeys: String, CodingKey {
        case title, body, state, base
        case maintainerCanModify = "maintainer_can_modify"
    }
}

// MARK: - Merging

/// How to merge a pull request.
public struct MergeOptions: Sendable, Hashable, Encodable {
    public var method: MergeMethod?
    /// Defaults to the repository's setting.
    public var commitTitle: String?
    public var commitMessage: String?
    /// Merges only if the head is still at this SHA.
    public var expectedHeadSHA: String?

    public init(method: MergeMethod? = nil, commitTitle: String? = nil, commitMessage: String? = nil, expectedHeadSHA: String? = nil) {
        self.method = method
        self.commitTitle = commitTitle
        self.commitMessage = commitMessage
        self.expectedHeadSHA = expectedHeadSHA
    }

    enum CodingKeys: String, CodingKey {
        case method = "merge_method"
        case commitTitle = "commit_title"
        case commitMessage = "commit_message"
        case expectedHeadSHA = "sha"
    }
}

/// The result of merging a pull request (`pull-request-merge-result`).
public struct MergeResult: Sendable, Hashable, Codable {
    /// The merge commit.
    public var sha: String
    public var isMerged: Bool
    public var message: String

    enum CodingKeys: String, CodingKey {
        case sha, message
        case isMerged = "merged"
    }
}

/// Whether a background merge goes straight in or through the merge queue.
public struct MergeAction: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Whatever the base branch requires.
    public static let `default`: Self = "default"
    public static let directMerge: Self = "direct_merge"
    public static let mergeQueue: Self = "merge_queue"
}

/// Where a background merge stands.
public struct BackgroundMergeStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending: Self = "pending"
    public static let merged: Self = "merged"
    /// In the merge queue.
    public static let enqueued: Self = "enqueued"
    public static let failed: Self = "failed"
}

/// A merge GitHub runs in the background (`pull-request-merge-async-result`).
public struct BackgroundMerge: Sendable, Hashable, Codable {
    /// What GitHub reported.
    public struct Details: Sendable, Hashable, Codable {
        public var message: String
        /// Pass to ``PullRequestsAPI/backgroundMerge(_:of:in:_:)`` to check on a pending merge.
        public var uuid: String?
        /// The merge commit, once merged.
        public var sha: String?
        public var mergeMethod: String?
        public var mergeAction: MergeAction?
        public var expectedHeadSHA: String?
        public var bypassesRules: Bool?

        enum CodingKeys: String, CodingKey {
            case message, uuid, sha
            case mergeMethod = "merge_method"
            case mergeAction = "merge_action"
            case expectedHeadSHA = "expected_head_sha"
            case bypassesRules = "bypass_rules"
        }
    }

    public var status: BackgroundMergeStatus
    public var details: Details
}

// MARK: - Reviews

/// A review's verdict, or `PENDING` before it's submitted.
public struct ReviewState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let approved: Self = "APPROVED"
    public static let changesRequested: Self = "CHANGES_REQUESTED"
    public static let commented: Self = "COMMENTED"
    public static let dismissed: Self = "DISMISSED"
    public static let pending: Self = "PENDING"
}

/// The verdict to submit with a review.
public struct ReviewEvent: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let approve: Self = "APPROVE"
    public static let requestChanges: Self = "REQUEST_CHANGES"
    public static let comment: Self = "COMMENT"
}

/// A pull request review (`pull-request-review`).
public struct PullRequestReview: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var user: SimpleUser?
    /// Markdown.
    public var body: String?
    public var state: ReviewState
    /// The head commit when the review was submitted.
    public var commitID: String?
    public var authorAssociation: AuthorAssociation?
    public var htmlURL: URL
    public var pullRequestURL: URL
    /// `nil` while the review is pending.
    public var submittedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case nodeID = "node_id"
        case commitID = "commit_id"
        case authorAssociation = "author_association"
        case htmlURL = "html_url"
        case pullRequestURL = "pull_request_url"
        case submittedAt = "submitted_at"
    }
}

/// Which side of a diff a comment is on.
public struct DiffSide: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// The old version, for deleted lines.
    public static let left: Self = "LEFT"
    /// The new version, for added or unchanged lines.
    public static let right: Self = "RIGHT"
}

/// Whether a review comment is on lines or on a whole file.
public struct ReviewCommentSubject: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let line: Self = "line"
    public static let file: Self = "file"
}

/// A comment on a pull request's diff (`pull-request-review-comment`, `review-comment`).
public struct ReviewComment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    /// The review the comment belongs to.
    public var reviewID: Int?
    /// The comment this one replies to.
    public var inReplyToID: Int?
    /// Markdown.
    public var body: String
    public var user: SimpleUser?
    public var authorAssociation: AuthorAssociation?
    public var reactions: ReactionSummary?
    /// The commented file.
    public var path: String
    /// The diff around the comment.
    public var diffHunk: String
    public var subjectType: ReviewCommentSubject?
    /// The last line commented on. `nil` when the line is gone from the current diff.
    public var line: Int?
    public var side: DiffSide?
    /// The first line, for a comment on several lines.
    public var startLine: Int?
    public var startSide: DiffSide?
    public var originalLine: Int?
    public var originalStartLine: Int?
    /// The line's index in the diff. Use ``line`` instead where you can.
    public var position: Int?
    public var originalPosition: Int?
    public var commitID: String
    public var originalCommitID: String
    public var url: URL
    public var htmlURL: URL
    public var pullRequestURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, user, reactions, path, line, side, position, url
        case nodeID = "node_id"
        case reviewID = "pull_request_review_id"
        case inReplyToID = "in_reply_to_id"
        case authorAssociation = "author_association"
        case diffHunk = "diff_hunk"
        case subjectType = "subject_type"
        case startLine = "start_line"
        case startSide = "start_side"
        case originalLine = "original_line"
        case originalStartLine = "original_start_line"
        case originalPosition = "original_position"
        case commitID = "commit_id"
        case originalCommitID = "original_commit_id"
        case htmlURL = "html_url"
        case pullRequestURL = "pull_request_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Where a review comment goes in the diff.
public enum ReviewCommentLocation: Sendable, Hashable {
    /// One line. `side` is `.right` for added or unchanged lines.
    case line(Int, side: DiffSide = .right)
    /// A range of lines, from `start` to `end`.
    case lines(start: Int, startSide: DiffSide = .right, end: Int, side: DiffSide = .right)
    /// The whole file.
    case file
    /// A line's index in the diff, counting from the first `@@` hunk header. Use `.line` where you can.
    case position(Int)
}

/// A review comment to add to a pull request.
public struct NewReviewComment: Sendable, Hashable, Encodable {
    /// Markdown.
    public var body: String
    /// The file to comment on.
    public var path: String
    public var location: ReviewCommentLocation
    /// The commit to comment on, usually the head. Required outside a review.
    public var commitID: String?

    public init(_ body: String, path: String, at location: ReviewCommentLocation, commitID: String? = nil) {
        self.body = body
        self.path = path
        self.location = location
        self.commitID = commitID
    }

    enum CodingKeys: String, CodingKey {
        case body, path, line, side, position
        case commitID = "commit_id"
        case startLine = "start_line"
        case startSide = "start_side"
        case subjectType = "subject_type"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(body, forKey: .body)
        try c.encode(path, forKey: .path)
        try c.encodeIfPresent(commitID, forKey: .commitID)
        switch location {
        case .line(let line, let side):
            try c.encode(line, forKey: .line)
            try c.encode(side, forKey: .side)
        case .lines(let start, let startSide, let end, let side):
            try c.encode(start, forKey: .startLine)
            try c.encode(startSide, forKey: .startSide)
            try c.encode(end, forKey: .line)
            try c.encode(side, forKey: .side)
        case .file:
            try c.encode(ReviewCommentSubject.file, forKey: .subjectType)
        case .position(let position):
            try c.encode(position, forKey: .position)
        }
    }
}

/// A review to start or submit.
public struct NewReview: Sendable, Hashable, Encodable {
    /// Markdown. Required to request changes or comment.
    public var body: String?
    /// `nil` leaves the review pending until you submit it.
    public var event: ReviewEvent?
    /// The commit to review. Defaults to the head.
    public var commitID: String?
    public var comments: [NewReviewComment]

    public init(body: String? = nil, event: ReviewEvent? = nil, commitID: String? = nil, comments: [NewReviewComment] = []) {
        self.body = body
        self.event = event
        self.commitID = commitID
        self.comments = comments
    }

    enum CodingKeys: String, CodingKey {
        case body, event, comments
        case commitID = "commit_id"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(event, forKey: .event)
        try c.encodeIfPresent(commitID, forKey: .commitID)
        if !comments.isEmpty { try c.encode(comments, forKey: .comments) }
    }
}

/// The people and teams asked to review a pull request (`pull-request-review-request`).
public struct ReviewRequests: Sendable, Hashable, Codable {
    public var users: [SimpleUser]
    public var teams: [Team]
}

// MARK: - Stacks

/// A chain of pull requests where each one builds on the one below it (`pull-request-stack`).
public struct PullRequestStack: Sendable, Hashable, Codable, Identifiable {
    /// The branch the bottom pull request merges into.
    public struct Base: Sendable, Hashable, Codable {
        public var ref: String
        public var sha: String?
    }

    /// A pull request in a stack.
    public struct Member: Sendable, Hashable, Codable, Identifiable {
        /// The member's head branch.
        public struct Head: Sendable, Hashable, Codable {
            public var ref: String
            public var sha: String
        }

        public var number: Int
        public var id: Int?
        public var nodeID: String?
        public var title: String?
        public var state: IssueState
        public var isDraft: Bool
        public var user: SimpleUser?
        public var head: Head?
        public var htmlURL: URL?
        public var mergedAt: Date?

        enum CodingKeys: String, CodingKey {
            case number, id, title, state, user, head
            case nodeID = "node_id"
            case isDraft = "draft"
            case htmlURL = "html_url"
            case mergedAt = "merged_at"
        }
    }

    public var id: Int
    public var number: Int
    public var nodeID: String
    public var base: Base
    public var isOpen: Bool
    /// Bottom first.
    public var pullRequests: [Member]
    public var url: URL
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, number, base, url
        case nodeID = "node_id"
        case isOpen = "open"
        case pullRequests = "pull_requests"
        case createdAt = "created_at"
    }
}
