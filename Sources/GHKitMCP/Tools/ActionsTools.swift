import Foundation
import GHKit
import MCP

/// GitHub Actions: workflows, runs, jobs, logs, artifacts, and deployment reviews.
enum ActionsTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reading + writing
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]

    static func repo(_ arguments: ToolArguments) throws(ToolFailure) -> (String, String) {
        (try arguments.string("owner"), try arguments.string("repo"))
    }

    /// A workflow argument as an ID when it's a number, or as a file name.
    static func workflow(_ arguments: ToolArguments) throws(ToolFailure) -> WorkflowID {
        let text = try arguments.string("workflow")
        return Int(text).map(WorkflowID.id) ?? .file(text)
    }

    static let workflowArgument = Schema.string("The workflow's file name, such as `ci.yml`, or its ID.")
    static let runArgument: [String: MCP.Value] = ["run_id": Schema.integer("The workflow run's ID.")]
    static let jobArgument: [String: MCP.Value] = ["job_id": Schema.integer("The job's ID, from `list_workflow_jobs`.")]

    static let states: KeyValuePairs<String, WorkflowRunFilter.State> = [
        "queued": .status(.queued), "in_progress": .status(.inProgress), "completed": .status(.completed),
        "waiting": .status(.waiting), "requested": .status(.requested), "pending": .status(.pending),
        "success": .conclusion(.success), "failure": .conclusion(.failure), "cancelled": .conclusion(.cancelled),
        "skipped": .conclusion(.skipped), "timed_out": .conclusion(.timedOut), "action_required": .conclusion(.actionRequired),
        "neutral": .conclusion(.neutral), "stale": .conclusion(.stale),
    ]

    static let reviewStates: KeyValuePairs<String, DeploymentReviewState> = ["approved": .approved, "rejected": .rejected]

    // MARK: Reading

    static let reading: [GitHubTool] = [
        GitHubTool(
            "list_workflows",
            title: "List workflows",
            description: "A repository's GitHub Actions workflows, with their file paths and whether they're enabled.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            return try await .page(context.client.actions.workflows(owner, repo, perPage: arguments.perPage), arguments, context)
        },
        GitHubTool(
            "list_workflow_runs",
            title: "List workflow runs",
            description: """
                Workflow runs, newest first, for a repository or one workflow: status, conclusion, branch, commit, and event. \
                Use it to find a failing run, then `list_workflow_jobs` and `get_job_logs`.
                """,
            schema: Schema.object(
                repository,
                [
                    "workflow": Schema.string("Only this workflow's runs: its file name, such as `ci.yml`, or its ID."),
                    "branch": Schema.string("Only runs for this branch."),
                    "event": Schema.string("Only runs started by this event, such as `push` or `pull_request`."),
                    "status": Schema.oneOf(states, "Only runs with this status, or with this conclusion once completed."),
                    "actor": Schema.string("Only runs this user started."),
                    "head_sha": Schema.string("Only runs for this commit."),
                    "created": Schema.string("When the run was created, in search syntax, such as `>=2024-01-01`."),
                ],
                Schema.paging,
                required: required
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let filter = WorkflowRunFilter(
                actor: try arguments.optionalString("actor"), branch: try arguments.optionalString("branch"),
                event: try arguments.optionalString("event"), state: try arguments.choice("status", from: states),
                created: try arguments.optionalString("created"), headSHA: try arguments.optionalString("head_sha"),
                excludesPullRequests: true)
            let actions = context.client.actions
            let list =
                try arguments.optionalString("workflow") == nil
                ? actions.runs(owner, repo, matching: filter, perPage: try arguments.perPage)
                : actions.runs(of: try workflow(arguments), in: owner, repo, matching: filter, perPage: try arguments.perPage)
            let cursor = try arguments.cursor(for: context.client)
            let page = try await context.client.page(list.request, at: cursor)
            return try .json(ListPage(items: page.items.map(RunSummary.init), nextCursor: page.next?.url.absoluteString))
        },
        GitHubTool(
            "get_workflow_run",
            title: "Get workflow run",
            description: "One workflow run, or one attempt of it, with its commit, pull requests, and links.",
            schema: Schema.object(
                repository, runArgument, ["attempt": Schema.integer("An attempt number, starting at 1. Defaults to the latest.", minimum: 1)],
                required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            return try .json(
                await context.client.actions.run(id: arguments.int("run_id"), attempt: arguments.optionalInt("attempt"), in: owner, repo))
        },
        GitHubTool(
            "list_workflow_jobs",
            title: "List workflow jobs",
            description: "A run's jobs with their steps, statuses, and conclusions. A failed step's number goes to `get_job_logs`.",
            schema: Schema.object(
                repository, runArgument,
                [
                    "attempt": Schema.integer("Only this attempt's jobs. Defaults to the latest attempt.", minimum: 1),
                    "all_attempts": Schema.boolean("Include the jobs of earlier attempts. Defaults to false."),
                ],
                Schema.paging,
                required: required + ["run_id"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let runID = try arguments.int("run_id")
            let actions = context.client.actions
            let list =
                if let attempt = try arguments.optionalInt("attempt") {
                    actions.jobs(ofRun: runID, attempt: attempt, in: owner, repo, perPage: try arguments.perPage)
                } else {
                    actions.jobs(
                        ofRun: runID, in: owner, repo, includingEarlierAttempts: try arguments.bool("all_attempts", default: false),
                        perPage: try arguments.perPage)
                }
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_job_logs",
            title: "Get job logs",
            description: "The end of a job's log, or of one step's log, as plain text. Errors are usually in the last lines.",
            schema: Schema.object(
                repository, jobArgument,
                [
                    "step": Schema.integer("Only this step's log: its `number` from `list_workflow_jobs`.", minimum: 1),
                    "lines": Schema.integer("How many lines from the end to return. Defaults to 300.", minimum: 1, maximum: 5000),
                ],
                required: required + ["job_id"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let jobID = try arguments.int("job_id")
            let actions = context.client.actions
            let log =
                if let step = try arguments.optionalInt("step") {
                    try await actions.stepLogs(step, ofJob: jobID, in: owner, repo)
                } else {
                    try await actions.jobLogs(id: jobID, in: owner, repo)
                }
            return .message(tail(log, lines: min(max(try arguments.optionalInt("lines") ?? 300, 1), 5000)))
        },
        GitHubTool(
            "list_workflow_run_artifacts",
            title: "List run artifacts",
            description: "The artifacts a workflow run uploaded: name, size, and whether they've expired.",
            schema: Schema.object(
                repository, runArgument, ["name": Schema.string("Only artifacts with exactly this name.")], Schema.paging,
                required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let list = context.client.actions.artifacts(
                ofRun: try arguments.int("run_id"), in: owner, repo, named: try arguments.optionalString("name"), perPage: try arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_pending_deployments",
            title: "List pending deployments",
            description: "A run's deployments that wait for an environment's reviewers or wait timer, and who can approve them.",
            schema: Schema.object(repository, runArgument, required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            return try .list(await context.client.actions.pendingDeployments(ofRun: arguments.int("run_id"), in: owner, repo))
        },
    ]

    // MARK: Writing

    static let writing: [GitHubTool] = [
        GitHubTool(
            "run_workflow",
            title: "Run workflow",
            kind: .write,
            description: "Starts a workflow that has a `workflow_dispatch` trigger, and returns the new run's ID when GitHub reports it.",
            schema: Schema.object(
                repository,
                [
                    "workflow": workflowArgument,
                    "ref": Schema.string("The branch or tag to run the workflow from."),
                    "inputs": Schema.anyObject("Values for the workflow's `workflow_dispatch` inputs, by name."),
                ],
                required: required + ["workflow", "ref"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let dispatch = try await context.client.actions.dispatchWorkflow(
                workflow(arguments), in: owner, repo, ref: arguments.string("ref"), inputs: inputs(arguments))
            guard let dispatch else { return .message("Started the workflow.") }
            return try .json(dispatch)
        },
        GitHubTool(
            "rerun_workflow_run",
            title: "Re-run workflow run",
            kind: .write,
            description: "Starts a new attempt of a finished run: every job, or only the failed ones.",
            schema: Schema.object(
                repository, runArgument,
                [
                    "failed_jobs_only": Schema.boolean("Re-run only the failed jobs and the jobs that depend on them. Defaults to false."),
                    "debug_logging": Schema.boolean("Turn on debug logs for the new attempt. Defaults to false."),
                ],
                required: required + ["run_id"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let runID = try arguments.int("run_id")
            try await context.client.actions.rerun(
                id: runID, in: owner, repo, failedJobsOnly: arguments.bool("failed_jobs_only", default: false),
                debugLogging: arguments.bool("debug_logging", default: false))
            return .message("Started a new attempt of run \(runID).")
        },
        GitHubTool(
            "rerun_workflow_job",
            title: "Re-run job",
            kind: .write,
            description: "Runs one job of a finished run again, with the jobs that depend on it.",
            schema: Schema.object(repository, jobArgument, required: required + ["job_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let jobID = try arguments.int("job_id")
            try await context.client.actions.rerunJob(id: jobID, in: owner, repo)
            return .message("Started job \(jobID) again.")
        },
        GitHubTool(
            "cancel_workflow_run",
            title: "Cancel workflow run",
            kind: .write,
            description: "Cancels a run that hasn't finished.",
            schema: Schema.object(
                repository, runArgument,
                ["force": Schema.boolean("Stop it even when `always()` steps would keep it going. Defaults to false.")],
                required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let runID = try arguments.int("run_id")
            try await context.client.actions.cancelRun(id: runID, in: owner, repo, force: arguments.bool("force", default: false))
            return .message("Asked GitHub to cancel run \(runID).")
        },
        GitHubTool(
            "approve_workflow_run",
            title: "Approve workflow run",
            kind: .write,
            idempotent: true,
            description: "Lets a run from a first-time contributor's fork start.",
            schema: Schema.object(repository, runArgument, required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let runID = try arguments.int("run_id")
            try await context.client.actions.approveRun(id: runID, in: owner, repo)
            return .message("Approved run \(runID).")
        },
        GitHubTool(
            "review_pending_deployments",
            title: "Review pending deployments",
            kind: .write,
            description: "Approves or rejects a run's deployments to environments that need a reviewer. Get the IDs from `list_pending_deployments`.",
            schema: Schema.object(
                repository, runArgument,
                [
                    "environment_ids": Schema.array(of: Schema.integer("An environment ID."), "The environments to approve or reject."),
                    "state": Schema.oneOf(reviewStates, "Whether the deployments go ahead."),
                    "comment": Schema.string("Why."),
                ],
                required: required + ["run_id", "environment_ids", "state", "comment"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            guard let state = try arguments.choice("state", from: reviewStates) else { throw ToolFailure("`state` is required.") }
            let environmentIDs = try arguments.ints("environment_ids")
            guard !environmentIDs.isEmpty else { throw ToolFailure("`environment_ids` needs at least one ID.") }
            return try .list(
                await context.client.actions.reviewPendingDeployments(
                    ofRun: arguments.int("run_id"), in: owner, repo, environmentIDs: environmentIDs, state: state, comment: arguments.text("comment")))
        },
        GitHubTool(
            "enable_workflow",
            title: "Enable workflow",
            kind: .write,
            idempotent: true,
            description: "Turns a disabled workflow back on.",
            schema: Schema.object(repository, ["workflow": workflowArgument], required: required + ["workflow"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            try await context.client.actions.enableWorkflow(workflow(arguments), in: owner, repo)
            return .message("Enabled the workflow.")
        },
        GitHubTool(
            "disable_workflow",
            title: "Disable workflow",
            kind: .write,
            idempotent: true,
            description: "Turns a workflow off, so nothing starts it until it's enabled again.",
            schema: Schema.object(repository, ["workflow": workflowArgument], required: required + ["workflow"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            try await context.client.actions.disableWorkflow(workflow(arguments), in: owner, repo)
            return .message("Disabled the workflow.")
        },
        GitHubTool(
            "delete_workflow_run",
            title: "Delete workflow run",
            kind: .destructive,
            idempotent: true,
            description: "Deletes a finished run and its logs. It can't be undone.",
            schema: Schema.object(repository, runArgument, required: required + ["run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let runID = try arguments.int("run_id")
            try await context.client.actions.deleteRun(id: runID, in: owner, repo)
            return .message("Deleted run \(runID).")
        },
    ]

    /// The `inputs` argument of `run_workflow`.
    static func inputs(_ arguments: ToolArguments) throws(ToolFailure) -> [String: JSONValue] {
        guard let object = try arguments.object("inputs") else { return [:] }
        do {
            return try JSONDecoder().decode([String: JSONValue].self, from: JSONEncoder().encode(object))
        } catch {
            throw ToolFailure("`inputs` must be an object of strings, numbers, and booleans.")
        }
    }

    /// The last `lines` lines of `text`, with a note when lines were left out.
    static func tail(_ text: String, lines: Int) -> String {
        let all = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard all.count > lines else { return text }
        return "[Showing the last \(lines) of \(all.count) lines.]\n" + all.suffix(lines).joined(separator: "\n")
    }
}

/// A workflow run for lists: what a model needs to pick one, without the repository objects.
struct RunSummary: Encodable {
    let id: Int
    let name: String?
    let title: String
    let workflowID: Int
    let runNumber: Int
    let attempt: Int?
    let event: String
    let status: CheckStatus?
    let conclusion: CheckConclusion?
    let branch: String?
    let sha: String
    let actor: String?
    let createdAt: Date
    let url: URL

    init(_ run: WorkflowRun) {
        id = run.id
        name = run.name
        title = run.displayTitle
        workflowID = run.workflowID
        runNumber = run.runNumber
        attempt = run.runAttempt
        event = run.event
        status = run.status
        conclusion = run.conclusion
        branch = run.headBranch
        sha = run.headSHA
        actor = run.actor?.login
        createdAt = run.createdAt
        url = run.htmlURL
    }
}
