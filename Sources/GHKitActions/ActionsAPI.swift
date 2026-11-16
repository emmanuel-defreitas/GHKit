import Foundation
import GHKitCore

extension GitHubClient {
    /// GitHub Actions: workflows, runs, jobs, logs, and artifacts.
    public var actions: ActionsAPI { ActionsAPI(client: scoped(to: .actions)) }
}

/// GitHub Actions endpoints. Reach them with `github.actions`.
///
///     let runs = github.actions.runs("octocat", "Hello-World", matching: WorkflowRunFilter(branch: "main"))
///     if let failed = try await runs.firstPage().items.first(where: { $0.conclusion == .failure }) {
///         try await github.actions.rerun(id: failed.id, in: "octocat", "Hello-World", failedJobsOnly: true)
///     }
///
/// Part of the `GHKitActions` library.
public struct ActionsAPI: Sendable {
    let client: GitHubClient

    func path(_ owner: String, _ name: String, _ rest: String = "") -> String {
        "/repos/\(escape(owner))/\(escape(name))/actions\(rest)"
    }

    private func workflowPath(_ workflow: WorkflowID, _ owner: String, _ name: String, _ rest: String = "") -> String {
        path(owner, name, "/workflows/\(escape(workflow.description))\(rest)")
    }

    private func runPath(_ id: Int, _ owner: String, _ name: String, _ rest: String = "") -> String {
        path(owner, name, "/runs/\(id)\(rest)")
    }

    // MARK: Workflows

    /// A repository's workflows. `GET /repos/{owner}/{repo}/actions/workflows`
    public func workflows(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<Workflow> {
        client.paginate(.wrappedList(path(owner, name, "/workflows"), key: "workflows", query: .query(("per_page", perPage))))
    }

    /// One workflow. `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}`
    public func workflow(_ workflow: WorkflowID, in owner: String, _ name: String) async throws(GitHubError) -> Workflow {
        try await client.value(GitHubRequest(.get, workflowPath(workflow, owner, name)))
    }

    /// Turns a workflow off, so nothing starts it. `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/disable`
    public func disableWorkflow(_ workflow: WorkflowID, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, workflowPath(workflow, owner, name, "/disable")))
    }

    /// Turns a workflow back on. `PUT /repos/{owner}/{repo}/actions/workflows/{workflow_id}/enable`
    public func enableWorkflow(_ workflow: WorkflowID, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, workflowPath(workflow, owner, name, "/enable")))
    }

    /// Starts a workflow that has a `workflow_dispatch` trigger.
    /// `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches`
    /// - Parameters:
    ///   - ref: The branch or tag to run the workflow file from.
    ///   - inputs: Values for the workflow's inputs, by name. Up to 25.
    /// - Returns: The new run, or `nil` when GitHub answers without its details.
    @discardableResult
    public func dispatchWorkflow(
        _ workflow: WorkflowID, in owner: String, _ name: String, ref: String, inputs: [String: JSONValue] = [:]
    ) async throws(GitHubError) -> WorkflowDispatch? {
        struct Body: Encodable, Sendable {
            let ref: String
            let inputs: [String: JSONValue]?
            let returnRunDetails = true

            enum CodingKeys: String, CodingKey {
                case ref, inputs
                case returnRunDetails = "return_run_details"
            }
        }
        let body = Body(ref: ref, inputs: inputs.isEmpty ? nil : inputs)
        return try await client.value(
            GitHubRequest(method: .post, target: .path(workflowPath(workflow, owner, name, "/dispatches")), body: .json(body)) { data in
                data.isEmpty ? nil : try GitHubJSON.decoder().decode(WorkflowDispatch.self, from: data)
            })
    }

    /// A workflow's billable runner time in the current billing cycle.
    /// `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/timing`
    public func workflowUsage(_ workflow: WorkflowID, in owner: String, _ name: String) async throws(GitHubError) -> WorkflowUsage {
        try await client.value(GitHubRequest(.get, workflowPath(workflow, owner, name, "/timing")))
    }

    // MARK: Runs

    /// A repository's workflow runs, newest first. `GET /repos/{owner}/{repo}/actions/runs`
    ///
    /// With a filter, GitHub returns at most 1,000 runs. Narrow it, such as with ``WorkflowRunFilter/created``, to reach older ones.
    public func runs(
        _ owner: String, _ name: String, matching filter: WorkflowRunFilter = WorkflowRunFilter(), perPage: Int = 100
    ) -> Paginated<WorkflowRun> {
        client.paginate(
            .wrappedList(path(owner, name, "/runs"), key: "workflow_runs", query: filter.query + .query(("per_page", perPage))))
    }

    /// One workflow's runs, newest first. `GET /repos/{owner}/{repo}/actions/workflows/{workflow_id}/runs`
    public func runs(
        of workflow: WorkflowID, in owner: String, _ name: String, matching filter: WorkflowRunFilter = WorkflowRunFilter(),
        perPage: Int = 100
    ) -> Paginated<WorkflowRun> {
        client.paginate(
            .wrappedList(
                workflowPath(workflow, owner, name, "/runs"), key: "workflow_runs", query: filter.query + .query(("per_page", perPage))))
    }

    /// One workflow run, or one attempt of it.
    /// `GET /repos/{owner}/{repo}/actions/runs/{run_id}`, `GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}`
    /// - Parameters:
    ///   - attempt: An attempt number, starting at 1. Defaults to the latest attempt.
    ///   - excludingPullRequests: Leaves ``WorkflowRun/pullRequests`` empty, which is faster.
    public func run(
        id: Int, attempt: Int? = nil, in owner: String, _ name: String, excludingPullRequests: Bool = false
    ) async throws(GitHubError) -> WorkflowRun {
        let rest = attempt.map { "/attempts/\($0)" } ?? ""
        return try await client.value(
            GitHubRequest(
                .get, runPath(id, owner, name, rest), query: .query(("exclude_pull_requests", excludingPullRequests ? true : nil))))
    }

    /// Deletes a completed run and its logs. `DELETE /repos/{owner}/{repo}/actions/runs/{run_id}`
    public func deleteRun(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, runPath(id, owner, name)))
    }

    /// Cancels a run that hasn't finished.
    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/cancel`, `POST /repos/{owner}/{repo}/actions/runs/{run_id}/force-cancel`
    /// - Parameter force: Stops the run even when `always()` steps would keep it going.
    /// - Throws: ``GitHubError`` with status 409 when the run has already finished.
    public func cancelRun(id: Int, in owner: String, _ name: String, force: Bool = false) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, runPath(id, owner, name, force ? "/force-cancel" : "/cancel")))
    }

    /// Starts a new attempt of a finished run.
    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun`, `POST /repos/{owner}/{repo}/actions/runs/{run_id}/rerun-failed-jobs`
    /// - Parameters:
    ///   - failedJobsOnly: Re-runs only the failed jobs and the jobs that depend on them.
    ///   - debugLogging: Turns on runner and step debug logs for the new attempt.
    public func rerun(
        id: Int, in owner: String, _ name: String, failedJobsOnly: Bool = false, debugLogging: Bool = false
    ) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let enableDebugLogging: Bool
            enum CodingKeys: String, CodingKey { case enableDebugLogging = "enable_debug_logging" }
        }
        let rest = failedJobsOnly ? "/rerun-failed-jobs" : "/rerun"
        try await client.value(GitHubRequest<Void>(.post, runPath(id, owner, name, rest), body: Body(enableDebugLogging: debugLogging)))
    }

    /// Lets a run from a first-time contributor's fork start. `POST /repos/{owner}/{repo}/actions/runs/{run_id}/approve`
    public func approveRun(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, runPath(id, owner, name, "/approve")))
    }

    /// A run's billable runner time and duration. `GET /repos/{owner}/{repo}/actions/runs/{run_id}/timing`
    public func runUsage(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> WorkflowRunUsage {
        try await client.value(GitHubRequest(.get, runPath(id, owner, name, "/timing")))
    }
}
