import Foundation
import GHKitCore

/// One job of a workflow run (`job`).
public struct Job: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var runID: Int
    /// Which attempt of the run the job belongs to.
    public var runAttempt: Int?
    public var workflowName: String?
    public var status: CheckStatus
    /// Set once ``status`` is ``CheckStatus/completed``.
    public var conclusion: CheckConclusion?
    public var steps: [Step]?
    public var headSHA: String
    public var headBranch: String?
    /// The `runs-on` labels the job asked for.
    public var labels: [String]
    public var runnerID: Int?
    public var runnerName: String?
    public var runnerGroupID: Int?
    public var runnerGroupName: String?
    public var url: URL
    public var htmlURL: URL?
    public var runURL: URL
    public var checkRunURL: URL
    /// GitHub's examples leave it out, though its schema requires it.
    public var createdAt: Date?
    public var startedAt: Date
    public var completedAt: Date?

    /// One step of a job.
    public struct Step: Sendable, Hashable, Codable {
        /// Starts at 1, in the order the steps run.
        public var number: Int
        public var name: String
        public var status: CheckStatus
        public var conclusion: CheckConclusion?
        public var startedAt: Date?
        public var completedAt: Date?

        enum CodingKeys: String, CodingKey {
            case number, name, status, conclusion
            case startedAt = "started_at"
            case completedAt = "completed_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, steps, labels, url
        case nodeID = "node_id"
        case runID = "run_id"
        case runAttempt = "run_attempt"
        case workflowName = "workflow_name"
        case headSHA = "head_sha"
        case headBranch = "head_branch"
        case runnerID = "runner_id"
        case runnerName = "runner_name"
        case runnerGroupID = "runner_group_id"
        case runnerGroupName = "runner_group_name"
        case htmlURL = "html_url"
        case runURL = "run_url"
        case checkRunURL = "check_run_url"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

/// Files a workflow run uploaded (`artifact`).
public struct Artifact: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    public var sizeInBytes: Int
    /// Whether GitHub deleted the files after the retention period. Expired artifacts can't be downloaded.
    public var isExpired: Bool
    /// A SHA-256 digest of the files, such as `sha256:…`.
    public var digest: String?
    /// The run that uploaded it.
    public var workflowRun: Run?
    public var url: URL
    /// Download it with ``ActionsAPI/downloadArtifact(id:in:_:)``, which follows this URL with credentials.
    public var archiveDownloadURL: URL
    public var createdAt: Date?
    public var updatedAt: Date?
    public var expiresAt: Date?

    /// The run that uploaded an artifact.
    public struct Run: Sendable, Hashable, Codable, Identifiable {
        public var id: Int?
        public var repositoryID: Int?
        public var headRepositoryID: Int?
        public var headBranch: String?
        public var headSHA: String?

        enum CodingKeys: String, CodingKey {
            case id
            case repositoryID = "repository_id"
            case headRepositoryID = "head_repository_id"
            case headBranch = "head_branch"
            case headSHA = "head_sha"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, digest, url
        case nodeID = "node_id"
        case sizeInBytes = "size_in_bytes"
        case isExpired = "expired"
        case workflowRun = "workflow_run"
        case archiveDownloadURL = "archive_download_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}

/// A reviewer's answer to a deployment waiting on an environment's protection rules.
public struct DeploymentReviewState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let approved: Self = "approved"
    public static let rejected: Self = "rejected"
    /// A comment without a decision.
    public static let pending: Self = "pending"
}

/// The environment a deployment review or pending deployment is for.
public struct EnvironmentReference: Sendable, Hashable, Codable {
    public var id: Int?
    public var nodeID: String?
    /// Such as `staging`.
    public var name: String?
    public var url: URL?
    public var htmlURL: URL?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, url
        case nodeID = "node_id"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A review of a run's deployments to protected environments (`environment-approvals`).
public struct DeploymentReview: Sendable, Hashable, Codable {
    public var environments: [EnvironmentReference]
    public var state: DeploymentReviewState
    public var user: SimpleUser
    public var comment: String
}

/// A deployment of a run that waits for an environment's protection rules (`pending-deployment`).
public struct PendingDeployment: Sendable, Hashable, Codable {
    public var environment: EnvironmentReference
    /// Minutes to wait before the deployment can go ahead.
    public var waitTimer: Int
    public var waitTimerStartedAt: Date?
    /// Whether the signed-in user is one of the ``reviewers``.
    public var currentUserCanApprove: Bool
    /// People and teams who can approve. One approval is enough.
    public var reviewers: [DeploymentReviewer]

    enum CodingKeys: String, CodingKey {
        case environment, reviewers
        case waitTimer = "wait_timer"
        case waitTimerStartedAt = "wait_timer_started_at"
        case currentUserCanApprove = "current_user_can_approve"
    }
}

/// A concurrency group a workflow run takes part in, with the run's items in it.
public struct ConcurrencyGroup: Sendable, Hashable, Codable {
    public var name: String
    /// May answer 404 once the group has no active items.
    public var url: URL
    /// The run's items that hold the group or wait for it. Empty once the run has left the group.
    public var members: [Member]

    /// A run, or one of its jobs, that holds a concurrency group or waits for it.
    public struct Member: Sendable, Hashable, Codable {
        public var runID: Int
        public var runName: String
        public var runURL: URL?
        public var runHTMLURL: URL?
        /// ``CheckStatus/inProgress`` while it holds the group, ``CheckStatus/pending`` while it waits.
        public var status: CheckStatus
        /// 0 while it holds the group; its place in the queue otherwise.
        public var position: Int
        public var positionURL: URL
        /// Set when a job, not the whole run, takes part.
        public var jobID: Int?
        public var jobName: String?
        public var jobURL: URL?
        public var jobHTMLURL: URL?

        enum CodingKeys: String, CodingKey {
            case status, position
            case runID = "run_id"
            case runName = "run_name"
            case runURL = "run_url"
            case runHTMLURL = "run_html_url"
            case positionURL = "position_url"
            case jobID = "job_id"
            case jobName = "job_name"
            case jobURL = "job_url"
            case jobHTMLURL = "job_html_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name = "group_name"
        case url = "group_url"
        case members = "group_members"
    }
}
