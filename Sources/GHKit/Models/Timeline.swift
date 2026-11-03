import Foundation

/// One entry in an issue or pull request timeline (`timeline-issue-events`).
///
/// Comments, commits, reviews, and cross-references have their own cases. Everything else, such as
/// labels, assignments, and state changes, is an ``IssueEvent``.
public enum TimelineEvent: Sendable, Hashable, Codable {
    /// A comment on the conversation.
    case commented(IssueComment)
    /// Another issue or pull request mentioned this one.
    case crossReferenced(CrossReference)
    /// A commit pushed to the pull request.
    case committed(GitCommit)
    /// A submitted review.
    case reviewed(PullRequestReview)
    /// Comments on lines of the diff.
    case lineCommented([ReviewComment])
    /// Comments on a commit.
    case commitCommented(commitID: String?, [CommitComment])
    /// Any other event.
    case event(IssueEvent)
    /// A kind of entry GHKit doesn't know yet, with its raw JSON.
    case unknown(IssueEventType, JSONValue)

    /// A mention of this issue from another issue or pull request.
    public struct CrossReference: Sendable, Hashable, Codable {
        /// Where the mention came from.
        public struct Source: Sendable, Hashable, Codable {
            /// `issue` for both issues and pull requests.
            public var type: String?
            public var issue: GitHubIssue?
        }

        public var actor: SimpleUser?
        public var source: Source
        public var createdAt: Date
        public var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case actor, source
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// What kind of entry this is, such as `commented` or `labeled`.
    public var type: IssueEventType {
        switch self {
        case .commented: "commented"
        case .crossReferenced: "cross-referenced"
        case .committed: "committed"
        case .reviewed: "reviewed"
        case .lineCommented: "line-commented"
        case .commitCommented: "commit-commented"
        case .event(let event): event.event
        case .unknown(let type, _): type
        }
    }

    enum CodingKeys: String, CodingKey {
        case event, comments
        case commitID = "commit_id"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(IssueEventType.self, forKey: .event) ?? "committed"
        switch type {
        case "commented": self = .commented(try IssueComment(from: decoder))
        case "cross-referenced": self = .crossReferenced(try CrossReference(from: decoder))
        case "committed": self = .committed(try GitCommit(from: decoder))
        case "reviewed":
            // Timeline reviews use lowercase states ("approved"); the reviews endpoint uses uppercase.
            var review = try PullRequestReview(from: decoder)
            review.state = ReviewState(rawValue: review.state.rawValue.uppercased())
            self = .reviewed(review)
        case "line-commented":
            self = .lineCommented(try c.decodeIfPresent([ReviewComment].self, forKey: .comments) ?? [])
        case "commit-commented":
            self = .commitCommented(
                commitID: try c.decodeIfPresent(String.self, forKey: .commitID),
                try c.decodeIfPresent([CommitComment].self, forKey: .comments) ?? [])
        default:
            if let event = try? IssueEvent(from: decoder) {
                self = .event(event)
            } else {
                self = .unknown(type, try JSONValue(from: decoder))
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .commented(let comment): try comment.encode(to: encoder)
        case .crossReferenced(let reference): try reference.encode(to: encoder)
        case .committed(let commit): try commit.encode(to: encoder)
        case .reviewed(let review): try review.encode(to: encoder)
        case .lineCommented(let comments):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(comments, forKey: .comments)
        case .commitCommented(let commitID, let comments):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(commitID, forKey: .commitID)
            try c.encode(comments, forKey: .comments)
        case .event(let event):
            try event.encode(to: encoder)
            return
        case .unknown(_, let json):
            try json.encode(to: encoder)
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .event)
    }
}
