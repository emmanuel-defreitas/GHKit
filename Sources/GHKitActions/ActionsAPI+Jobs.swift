import Foundation
import GHKitCore

// Jobs, logs, artifacts, and deployment reviews.
extension ActionsAPI {
    // MARK: Jobs

    /// A run's jobs. `GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs`
    /// - Parameter includingEarlierAttempts: Adds the jobs of attempts before the latest one.
    public func jobs(
        ofRun runID: Int, in owner: String, _ name: String, includingEarlierAttempts: Bool = false, perPage: Int = 100
    ) -> Paginated<Job> {
        client.paginate(
            .wrappedList(
                path(owner, name, "/runs/\(runID)/jobs"), key: "jobs",
                query: .query(("filter", includingEarlierAttempts ? "all" : nil), ("per_page", perPage))))
    }

    /// The jobs of one attempt of a run. `GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}/jobs`
    public func jobs(ofRun runID: Int, attempt: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<Job> {
        client.paginate(
            .wrappedList(path(owner, name, "/runs/\(runID)/attempts/\(attempt)/jobs"), key: "jobs", query: .query(("per_page", perPage))))
    }

    /// One job. `GET /repos/{owner}/{repo}/actions/jobs/{job_id}`
    public func job(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Job {
        try await client.value(GitHubRequest(.get, path(owner, name, "/jobs/\(id)")))
    }

    /// Runs one job of a finished run again, with the jobs that depend on it.
    /// `POST /repos/{owner}/{repo}/actions/jobs/{job_id}/rerun`
    /// - Parameter debugLogging: Turns on runner and step debug logs.
    public func rerunJob(id: Int, in owner: String, _ name: String, debugLogging: Bool = false) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let enableDebugLogging: Bool
            enum CodingKeys: String, CodingKey { case enableDebugLogging = "enable_debug_logging" }
        }
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/jobs/\(id)/rerun"), body: Body(enableDebugLogging: debugLogging)))
    }

    // MARK: Logs

    /// A job's log as plain text. GitHub redirects to the file, and URLSession follows.
    /// `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs`
    public func jobLogs(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> String {
        try await text(path(owner, name, "/jobs/\(id)/logs"))
    }

    /// One step's log as plain text. `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/steps/{step_number}/logs`
    /// - Parameter step: The step's ``Job/Step/number``.
    public func stepLogs(_ step: Int, ofJob jobID: Int, in owner: String, _ name: String) async throws(GitHubError) -> String {
        try await text(path(owner, name, "/jobs/\(jobID)/steps/\(step)/logs"))
    }

    /// A zip archive of every job's logs in a run, or in one attempt of it.
    /// `GET /repos/{owner}/{repo}/actions/runs/{run_id}/logs`, `GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}/logs`
    public func runLogs(id: Int, attempt: Int? = nil, in owner: String, _ name: String) async throws(GitHubError) -> Data {
        let rest = (attempt.map { "/attempts/\($0)" } ?? "") + "/logs"
        return try await client.value(GitHubRequest(method: .get, target: .path(path(owner, name, "/runs/\(id)\(rest)")), decode: { $0 }))
    }

    /// Deletes a run's logs. `DELETE /repos/{owner}/{repo}/actions/runs/{run_id}/logs`
    public func deleteRunLogs(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/runs/\(id)/logs")))
    }

    private func text(_ path: String) async throws(GitHubError) -> String {
        try await client.value(GitHubRequest(method: .get, target: .path(path)) { String(decoding: $0, as: UTF8.self) })
    }

    // MARK: Artifacts

    /// A repository's artifacts, newest first. `GET /repos/{owner}/{repo}/actions/artifacts`
    /// - Parameter named: Only artifacts with exactly this name.
    public func artifacts(_ owner: String, _ name: String, named artifactName: String? = nil, perPage: Int = 100) -> Paginated<Artifact> {
        client.paginate(
            .wrappedList(path(owner, name, "/artifacts"), key: "artifacts", query: .query(("name", artifactName), ("per_page", perPage))))
    }

    /// The artifacts a run uploaded. `GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts`
    /// - Parameters:
    ///   - named: Only artifacts with exactly this name.
    ///   - ascending: Oldest first. GitHub lists newest first by default.
    public func artifacts(
        ofRun runID: Int, in owner: String, _ name: String, named artifactName: String? = nil, ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<Artifact> {
        let direction = ascending.map { $0 ? "asc" : "desc" }
        return client.paginate(
            .wrappedList(
                path(owner, name, "/runs/\(runID)/artifacts"), key: "artifacts",
                query: .query(("name", artifactName), ("direction", direction), ("per_page", perPage))))
    }

    /// One artifact. `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`
    public func artifact(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Artifact {
        try await client.value(GitHubRequest(.get, path(owner, name, "/artifacts/\(id)")))
    }

    /// Deletes an artifact. `DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}`
    public func deleteArtifact(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/artifacts/\(id)")))
    }

    /// An artifact's files as a zip archive. GitHub redirects to the file, and URLSession follows.
    /// `GET /repos/{owner}/{repo}/actions/artifacts/{artifact_id}/{archive_format}`
    /// - Throws: ``GitHubError`` with status 410 when the artifact has expired.
    public func downloadArtifact(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Data {
        try await client.value(GitHubRequest(method: .get, target: .path(path(owner, name, "/artifacts/\(id)/zip")), decode: { $0 }))
    }

    // MARK: Deployment reviews

    /// Who approved or rejected a run's deployments to protected environments.
    /// `GET /repos/{owner}/{repo}/actions/runs/{run_id}/approvals`
    public func deploymentReviews(ofRun runID: Int, in owner: String, _ name: String) async throws(GitHubError) -> [DeploymentReview] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/runs/\(runID)/approvals")))
    }

    /// A run's deployments that wait for an environment's protection rules.
    /// `GET /repos/{owner}/{repo}/actions/runs/{run_id}/pending_deployments`
    public func pendingDeployments(ofRun runID: Int, in owner: String, _ name: String) async throws(GitHubError) -> [PendingDeployment] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/runs/\(runID)/pending_deployments")))
    }

    /// Approves or rejects a run's deployments to environments that need a reviewer.
    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/pending_deployments`
    /// - Parameter environmentIDs: From ``PendingDeployment/environment``.
    /// - Returns: The deployments that go ahead.
    @discardableResult
    public func reviewPendingDeployments(
        ofRun runID: Int, in owner: String, _ name: String, environmentIDs: [Int], state: DeploymentReviewState, comment: String
    ) async throws(GitHubError) -> [Deployment] {
        struct Body: Encodable, Sendable {
            let environmentIDs: [Int]
            let state: DeploymentReviewState
            let comment: String
            enum CodingKeys: String, CodingKey {
                case state, comment
                case environmentIDs = "environment_ids"
            }
        }
        let body = Body(environmentIDs: environmentIDs, state: state, comment: comment)
        return try await client.value(GitHubRequest(.post, path(owner, name, "/runs/\(runID)/pending_deployments"), body: body))
    }

    /// Answers a custom deployment protection rule for a run, as the GitHub App that owns the rule.
    /// `POST /repos/{owner}/{repo}/actions/runs/{run_id}/deployment_protection_rule`
    /// - Parameters:
    ///   - environment: The environment's name.
    ///   - state: ``DeploymentReviewState/approved`` or ``DeploymentReviewState/rejected``. Without it, `comment`
    ///     is required and posts a status update instead.
    public func reviewDeploymentProtectionRule(
        ofRun runID: Int, in owner: String, _ name: String, environment: String, state: DeploymentReviewState? = nil, comment: String? = nil
    ) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let environmentName: String
            let state: DeploymentReviewState?
            let comment: String?
            enum CodingKeys: String, CodingKey {
                case state, comment
                case environmentName = "environment_name"
            }
        }
        let body = Body(environmentName: environment, state: state, comment: comment)
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/runs/\(runID)/deployment_protection_rule"), body: body))
    }

    // MARK: Concurrency

    /// The concurrency groups a run takes part in, with its items in each.
    /// `GET /repos/{owner}/{repo}/actions/runs/{run_id}/concurrency_groups`
    public func concurrencyGroups(ofRun runID: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<ConcurrencyGroup> {
        client.paginate(
            .wrappedList(
                path(owner, name, "/runs/\(runID)/concurrency_groups"), key: "concurrency_groups", query: .query(("per_page", perPage))))
    }
}
