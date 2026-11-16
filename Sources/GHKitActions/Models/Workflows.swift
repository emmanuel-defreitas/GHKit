import Foundation
import GHKitCore

/// A workflow, by its ID or by its file name in `.github/workflows`.
///
///     try await github.actions.workflow("ci.yml", in: "octocat", "Hello-World")
///     try await github.actions.workflow(161335, in: "octocat", "Hello-World")
public enum WorkflowID: Sendable, Hashable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, CustomStringConvertible {
    case id(Int)
    /// The file name, such as `ci.yml`.
    case file(String)

    public init(integerLiteral value: Int) { self = .id(value) }
    public init(stringLiteral value: String) { self = .file(value) }

    public var description: String {
        switch self {
        case .id(let id): String(id)
        case .file(let name): name
        }
    }
}

/// A GitHub Actions workflow (`workflow`).
public struct Workflow: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    /// Such as `.github/workflows/ci.yml`.
    public var path: String
    public var state: WorkflowState
    public var url: URL
    public var htmlURL: URL
    /// An SVG badge showing the latest run's result.
    public var badgeURL: URL
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, path, state, url
        case nodeID = "node_id"
        case htmlURL = "html_url"
        case badgeURL = "badge_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

/// Whether a workflow can run.
public struct WorkflowState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let active: Self = "active"
    /// The workflow file was removed.
    public static let deleted: Self = "deleted"
    /// Off because the repository is a fork.
    public static let disabledFork: Self = "disabled_fork"
    /// Off because the repository had no activity for 60 days.
    public static let disabledInactivity: Self = "disabled_inactivity"
    public static let disabledManually: Self = "disabled_manually"
}

/// One run of a workflow (`workflow-run`).
public struct WorkflowRun: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    /// The workflow's name.
    public var name: String?
    /// The run's title: a commit message or pull request title, or the workflow's `run-name`.
    public var displayTitle: String
    public var workflowID: Int
    /// The workflow file and the ref it came from, such as `.github/workflows/build.yml@main`.
    public var path: String
    /// Counts up for each run of the workflow.
    public var runNumber: Int
    /// Starts at 1 and counts re-runs.
    public var runAttempt: Int?
    /// The event that started the run, such as `push` or `pull_request`.
    public var event: String
    public var status: CheckStatus?
    /// Set once ``status`` is ``CheckStatus/completed``.
    public var conclusion: CheckConclusion?
    public var headBranch: String?
    public var headSHA: String
    public var headCommit: SimpleCommit?
    public var repository: Repository
    /// Where the head commit is: a fork for a pull request from one.
    public var headRepository: Repository?
    /// Open pull requests from the head branch. Empty for runs from forks.
    public var pullRequests: [PullRequestReference]?
    /// Reusable workflows the run called.
    public var referencedWorkflows: [ReferencedWorkflow]?
    /// Who started the run first.
    public var actor: SimpleUser?
    /// Who started this attempt.
    public var triggeringActor: SimpleUser?
    public var checkSuiteID: Int?
    public var checkSuiteNodeID: String?
    public var url: URL
    public var htmlURL: URL
    public var jobsURL: URL
    public var logsURL: URL
    public var artifactsURL: URL
    public var checkSuiteURL: URL
    public var cancelURL: URL
    public var rerunURL: URL
    public var previousAttemptURL: URL?
    public var workflowURL: URL
    public var createdAt: Date
    public var updatedAt: Date
    /// When this attempt started.
    public var runStartedAt: Date?

    /// A reusable workflow a run called (`referenced-workflow`).
    public struct ReferencedWorkflow: Sendable, Hashable, Codable {
        /// Such as `octocat/Hello-World/.github/workflows/deploy.yml@main`.
        public var path: String
        public var sha: String
        public var ref: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, event, status, conclusion, repository, actor, url
        case nodeID = "node_id"
        case displayTitle = "display_title"
        case workflowID = "workflow_id"
        case runNumber = "run_number"
        case runAttempt = "run_attempt"
        case headBranch = "head_branch"
        case headSHA = "head_sha"
        case headCommit = "head_commit"
        case headRepository = "head_repository"
        case pullRequests = "pull_requests"
        case referencedWorkflows = "referenced_workflows"
        case triggeringActor = "triggering_actor"
        case checkSuiteID = "check_suite_id"
        case checkSuiteNodeID = "check_suite_node_id"
        case htmlURL = "html_url"
        case jobsURL = "jobs_url"
        case logsURL = "logs_url"
        case artifactsURL = "artifacts_url"
        case checkSuiteURL = "check_suite_url"
        case cancelURL = "cancel_url"
        case rerunURL = "rerun_url"
        case previousAttemptURL = "previous_attempt_url"
        case workflowURL = "workflow_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runStartedAt = "run_started_at"
    }
}

/// Narrows workflow run lists.
public struct WorkflowRunFilter: Sendable, Hashable {
    /// A run's status or, once it's completed, its conclusion.
    public enum State: Sendable, Hashable, CustomStringConvertible {
        case status(CheckStatus)
        case conclusion(CheckConclusion)

        public var description: String {
            switch self {
            case .status(let status): status.rawValue
            case .conclusion(let conclusion): conclusion.rawValue
            }
        }
    }

    /// The login of the user who started the run.
    public var actor: String?
    public var branch: String?
    /// Such as `push` or `pull_request`.
    public var event: String?
    public var state: State?
    /// When the run was created, in search syntax, such as `>=2024-01-01` or `2024-01-01..2024-01-31`.
    public var created: String?
    public var headSHA: String?
    public var checkSuiteID: Int?
    /// Leaves ``WorkflowRun/pullRequests`` empty, which makes the list faster.
    public var excludesPullRequests: Bool

    public init(
        actor: String? = nil, branch: String? = nil, event: String? = nil, state: State? = nil, created: String? = nil,
        headSHA: String? = nil, checkSuiteID: Int? = nil, excludesPullRequests: Bool = false
    ) {
        self.actor = actor
        self.branch = branch
        self.event = event
        self.state = state
        self.created = created
        self.headSHA = headSHA
        self.checkSuiteID = checkSuiteID
        self.excludesPullRequests = excludesPullRequests
    }

    var query: [URLQueryItem] {
        .query(
            ("actor", actor), ("branch", branch), ("event", event), ("status", state), ("created", created), ("head_sha", headSHA),
            ("check_suite_id", checkSuiteID), ("exclude_pull_requests", excludesPullRequests ? true : nil))
    }
}

/// The run a workflow dispatch started (`workflow-dispatch-response`).
public struct WorkflowDispatch: Sendable, Hashable, Codable {
    public var workflowRunID: Int
    public var runURL: URL
    public var htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case workflowRunID = "workflow_run_id"
        case runURL = "run_url"
        case htmlURL = "html_url"
    }
}

/// Billable runner time for a workflow in the current billing cycle (`workflow-usage`).
public struct WorkflowUsage: Sendable, Hashable, Codable {
    /// By runner OS: `UBUNTU`, `MACOS`, and `WINDOWS`.
    public var billable: [String: BillableTime]
}

/// Billable runner time and duration for one workflow run (`workflow-run-usage`).
public struct WorkflowRunUsage: Sendable, Hashable, Codable {
    /// By runner OS: `UBUNTU`, `MACOS`, and `WINDOWS`.
    public var billable: [String: BillableTime]
    /// How long the run took, in milliseconds.
    public var runDurationMilliseconds: Int?

    enum CodingKeys: String, CodingKey {
        case billable
        case runDurationMilliseconds = "run_duration_ms"
    }
}

/// Runner time on one OS. Runs in public repositories and on self-hosted runners aren't billed.
public struct BillableTime: Sendable, Hashable, Codable {
    public var totalMilliseconds: Int?
    /// How many jobs ran, for a workflow run.
    public var jobs: Int?
    /// Each job's time, for a workflow run.
    public var jobRuns: [JobTime]?

    /// One job's billable time.
    public struct JobTime: Sendable, Hashable, Codable {
        public var jobID: Int
        public var durationMilliseconds: Int

        enum CodingKeys: String, CodingKey {
            case jobID = "job_id"
            case durationMilliseconds = "duration_ms"
        }
    }

    enum CodingKeys: String, CodingKey {
        case jobs
        case totalMilliseconds = "total_ms"
        case jobRuns = "job_runs"
    }
}
