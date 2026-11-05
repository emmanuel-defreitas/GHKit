import Foundation
import GHKitCore

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
    /// Up to 250 commits, oldest first. Use ``RepositoriesAPI/comparedCommits(_:_:in:_:perPage:)`` for all of them.
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
