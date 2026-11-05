import Foundation

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
