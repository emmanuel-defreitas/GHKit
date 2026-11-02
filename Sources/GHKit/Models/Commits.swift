import Foundation

/// A commit as the REST API shows it, with its GitHub authors and changed files (`commit`).
public struct Commit: Sendable, Hashable, Codable, Identifiable {
    public var sha: String
    public var nodeID: String?
    public var url: URL?
    public var htmlURL: URL?
    public var commentsURL: URL?
    public var commit: Details
    /// The GitHub account that wrote the commit, or `nil` when the email matches no account.
    public var author: SimpleUser?
    /// The GitHub account that committed, or `nil` when the email matches no account.
    public var committer: SimpleUser?
    public var parents: [GitCommit.Pointer]
    public var stats: Stats?
    /// Only included when fetching a single commit.
    public var files: [DiffEntry]?

    public var id: String { sha }

    /// The Git data behind a commit.
    public struct Details: Sendable, Hashable, Codable {
        public var url: URL?
        public var author: GitActor?
        public var committer: GitActor?
        public var message: String
        public var commentCount: Int?
        public var tree: GitCommit.Pointer?
        public var verification: GitCommit.Verification?

        enum CodingKeys: String, CodingKey {
            case url, author, committer, message, tree, verification
            case commentCount = "comment_count"
        }
    }

    /// Lines added and removed.
    public struct Stats: Sendable, Hashable, Codable {
        public var additions: Int?
        public var deletions: Int?
        public var total: Int?
    }

    enum CodingKeys: String, CodingKey {
        case sha, url, commit, author, committer, parents, stats, files
        case nodeID = "node_id"
        case htmlURL = "html_url"
        case commentsURL = "comments_url"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sha = try c.decode(String.self, forKey: .sha)
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        htmlURL = try c.decodeIfPresent(URL.self, forKey: .htmlURL)
        commentsURL = try c.decodeIfPresent(URL.self, forKey: .commentsURL)
        commit = try c.decode(Details.self, forKey: .commit)
        // GitHub sends `{}` instead of `null` when no account matches.
        author = try? c.decodeIfPresent(SimpleUser.self, forKey: .author)
        committer = try? c.decodeIfPresent(SimpleUser.self, forKey: .committer)
        parents = try c.decodeIfPresent([GitCommit.Pointer].self, forKey: .parents) ?? []
        stats = try c.decodeIfPresent(Stats.self, forKey: .stats)
        files = try c.decodeIfPresent([DiffEntry].self, forKey: .files)
    }
}

/// One file changed by a commit or comparison (`diff-entry`).
public struct DiffEntry: Sendable, Hashable, Codable {
    public var sha: String?
    public var filename: String
    public var status: DiffStatus
    public var additions: Int
    public var deletions: Int
    public var changes: Int
    public var blobURL: URL?
    public var rawURL: URL?
    public var contentsURL: URL?
    /// The unified diff. Missing for binary or very large files.
    public var patch: String?
    /// The old path, for renamed files.
    public var previousFilename: String?

    enum CodingKeys: String, CodingKey {
        case sha, filename, status, additions, deletions, changes, patch
        case blobURL = "blob_url"
        case rawURL = "raw_url"
        case contentsURL = "contents_url"
        case previousFilename = "previous_filename"
    }
}

/// How a file changed.
public struct DiffStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let added: Self = "added"
    public static let removed: Self = "removed"
    public static let modified: Self = "modified"
    public static let renamed: Self = "renamed"
    public static let copied: Self = "copied"
    public static let changed: Self = "changed"
    public static let unchanged: Self = "unchanged"
}

/// How two refs relate, with the commits and files between them (`commit-comparison`).
public struct CommitComparison: Sendable, Hashable, Codable {
    public var status: ComparisonStatus
    /// Commits in head that base doesn't have.
    public var aheadBy: Int
    /// Commits in base that head doesn't have.
    public var behindBy: Int
    public var totalCommits: Int
    public var baseCommit: Commit
    /// The newest commit both refs share.
    public var mergeBaseCommit: Commit
    /// Up to 250 commits, oldest first. Page through them with `page` for more.
    public var commits: [Commit]
    /// Up to 300 changed files.
    public var files: [DiffEntry]?
    public var url: URL
    public var htmlURL: URL
    /// A link that keeps working when the refs move.
    public var permalinkURL: URL
    public var diffURL: URL
    public var patchURL: URL

    enum CodingKeys: String, CodingKey {
        case status, commits, files, url
        case aheadBy = "ahead_by"
        case behindBy = "behind_by"
        case totalCommits = "total_commits"
        case baseCommit = "base_commit"
        case mergeBaseCommit = "merge_base_commit"
        case htmlURL = "html_url"
        case permalinkURL = "permalink_url"
        case diffURL = "diff_url"
        case patchURL = "patch_url"
    }
}

/// How the head of a comparison relates to its base.
public struct ComparisonStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let ahead: Self = "ahead"
    public static let behind: Self = "behind"
    public static let diverged: Self = "diverged"
    public static let identical: Self = "identical"
}

/// A text format for a commit or comparison.
public enum DiffFormat: String, Sendable, Hashable {
    /// A unified diff.
    case diff
    /// A series of `git format-patch` emails, one per commit.
    case patch
}

/// A comment on a commit, or on one line of it (`commit-comment`).
public struct CommitComment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var body: String
    /// The commented file, or `nil` for a comment on the whole commit.
    public var path: String?
    /// The line's index in the diff.
    public var position: Int?
    public var line: Int?
    public var commitID: String
    public var user: SimpleUser?
    public var authorAssociation: AuthorAssociation
    public var reactions: ReactionSummary?
    public var url: URL
    public var htmlURL: URL
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body, path, position, line, user, reactions, url
        case nodeID = "node_id"
        case commitID = "commit_id"
        case authorAssociation = "author_association"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// How the author of a comment, issue, or pull request relates to the repository.
public struct AuthorAssociation: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let owner: Self = "OWNER"
    public static let member: Self = "MEMBER"
    public static let collaborator: Self = "COLLABORATOR"
    public static let contributor: Self = "CONTRIBUTOR"
    public static let firstTimeContributor: Self = "FIRST_TIME_CONTRIBUTOR"
    public static let firstTimer: Self = "FIRST_TIMER"
    public static let mannequin: Self = "MANNEQUIN"
    /// No association, shown as `NONE`.
    public static let unaffiliated: Self = "NONE"
}

/// A status reported on a commit by a CI system or other tool (`status`, `simple-commit-status`).
public struct CommitStatus: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    public var state: CommitState
    /// Tells statuses from different tools apart, such as `ci/build`.
    public var context: String
    public var description: String?
    /// Where to see details, such as the build log.
    public var targetURL: URL?
    public var avatarURL: URL?
    public var creator: SimpleUser?
    /// Whether branch protection requires this status. Only in combined statuses.
    public var isRequired: Bool?
    public var url: URL?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, state, context, description, creator, url
        case nodeID = "node_id"
        case targetURL = "target_url"
        case avatarURL = "avatar_url"
        case isRequired = "required"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// The state of a commit status.
public struct CommitState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let pending: Self = "pending"
    public static let success: Self = "success"
    public static let failure: Self = "failure"
    public static let error: Self = "error"
}

/// The latest status for each context on a ref, and the overall state (`combined-commit-status`).
public struct CombinedStatus: Sendable, Hashable, Codable {
    /// `failure` if any status failed or errored, `pending` if any is pending or none exist, otherwise `success`.
    public var state: CommitState
    public var sha: String
    public var totalCount: Int
    public var statuses: [CommitStatus]
    public var repository: Repository?
    public var commitURL: URL?
    public var url: URL?

    enum CodingKeys: String, CodingKey {
        case state, sha, statuses, repository, url
        case totalCount = "total_count"
        case commitURL = "commit_url"
    }
}

/// A status to report on a commit.
public struct NewCommitStatus: Sendable, Hashable, Encodable {
    public var state: CommitState
    /// Defaults to `default`. Use one context per tool, such as `ci/build`.
    public var context: String?
    /// A short summary, such as "Build passed in 2m".
    public var description: String?
    public var targetURL: URL?

    public init(_ state: CommitState, context: String? = nil, description: String? = nil, targetURL: URL? = nil) {
        self.state = state
        self.context = context
        self.description = description
        self.targetURL = targetURL
    }

    enum CodingKeys: String, CodingKey {
        case state, context, description
        case targetURL = "target_url"
    }
}
