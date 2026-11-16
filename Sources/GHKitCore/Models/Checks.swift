import Foundation

/// Where a check run, check suite, workflow run, or job is in its life.
public struct CheckStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let queued: Self = "queued"
    public static let inProgress: Self = "in_progress"
    /// Finished. The conclusion says how.
    public static let completed: Self = "completed"
    /// Waiting for an environment's protection rules, such as a required reviewer.
    public static let waiting: Self = "waiting"
    public static let requested: Self = "requested"
    /// Waiting for a concurrency group to free up.
    public static let pending: Self = "pending"
}

/// How a check run, check suite, workflow run, or job finished.
public struct CheckConclusion: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let success: Self = "success"
    public static let failure: Self = "failure"
    public static let neutral: Self = "neutral"
    public static let cancelled: Self = "cancelled"
    public static let skipped: Self = "skipped"
    public static let timedOut: Self = "timed_out"
    /// The check needs someone to act, such as approving a run from a fork.
    public static let actionRequired: Self = "action_required"
    /// Superseded by a newer run.
    public static let stale: Self = "stale"
    /// The workflow file is invalid, so the run never started.
    public static let startupFailure: Self = "startup_failure"
}

/// A pull request a check or workflow run belongs to, with the commits at its ends (`pull-request-minimal`).
public struct PullRequestReference: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var number: Int
    public var url: URL
    public var head: Branch
    public var base: Branch

    /// One end of the pull request.
    public struct Branch: Sendable, Hashable, Codable {
        public var ref: String
        public var sha: String
        public var repository: Repository

        /// The repository the branch is in.
        public struct Repository: Sendable, Hashable, Codable, Identifiable {
            public var id: Int
            public var name: String
            public var url: URL
        }

        enum CodingKeys: String, CodingKey {
            case ref, sha
            case repository = "repo"
        }
    }
}

/// The commit a check suite or workflow run ran on (`simple-commit`).
public struct SimpleCommit: Sendable, Hashable, Codable, Identifiable {
    /// The commit SHA.
    public var id: String
    public var treeID: String
    public var message: String
    public var timestamp: Date
    public var author: GitActor?
    public var committer: GitActor?

    enum CodingKeys: String, CodingKey {
        case id, message, timestamp, author, committer
        case treeID = "tree_id"
    }
}
