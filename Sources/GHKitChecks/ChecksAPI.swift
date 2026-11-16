import Foundation
import GHKitCore

extension GitHubClient {
    /// Check runs and check suites.
    public var checks: ChecksAPI { ChecksAPI(client: scoped(to: .checks)) }
}

/// Check run and check suite endpoints. Reach them with `github.checks`.
///
///     let runs = try await github.checks.runs(for: "main", in: "octocat", "Hello-World").collect()
///     let failing = runs.filter { $0.conclusion == .failure }.map(\.name)
///
/// Only GitHub Apps can create and update check runs and suites; see ``NewCheckRun``.
///
/// Part of the `GHKitChecks` library.
public struct ChecksAPI: Sendable {
    let client: GitHubClient

    func path(_ owner: String, _ name: String, _ rest: String) -> String {
        "/repos/\(escape(owner))/\(escape(name))\(rest)"
    }

    // MARK: Check runs

    /// Reports a check on a commit, as a GitHub App. `POST /repos/{owner}/{repo}/check-runs`
    @discardableResult
    public func createRun(_ run: NewCheckRun, in owner: String, _ name: String) async throws(GitHubError) -> CheckRun {
        try await client.value(GitHubRequest(.post, path(owner, name, "/check-runs"), body: run))
    }

    /// One check run. `GET /repos/{owner}/{repo}/check-runs/{check_run_id}`
    public func run(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> CheckRun {
        try await client.value(GitHubRequest(.get, path(owner, name, "/check-runs/\(id)")))
    }

    /// Changes a check run, as the GitHub App that created it. `PATCH /repos/{owner}/{repo}/check-runs/{check_run_id}`
    @discardableResult
    public func updateRun(id: Int, in owner: String, _ name: String, _ update: CheckRunUpdate) async throws(GitHubError) -> CheckRun {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/check-runs/\(id)"), body: update))
    }

    /// The notes a check run left on lines of files. `GET /repos/{owner}/{repo}/check-runs/{check_run_id}/annotations`
    public func annotations(ofRun runID: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<CheckAnnotation> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/check-runs/\(runID)/annotations"), query: .query(("per_page", perPage))))
    }

    /// Asks the app that reported a check run to run it again. `POST /repos/{owner}/{repo}/check-runs/{check_run_id}/rerequest`
    public func rerequestRun(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/check-runs/\(id)/rerequest")))
    }

    /// The check runs on a commit, newest first. `GET /repos/{owner}/{repo}/commits/{ref}/check-runs`
    /// - Parameters:
    ///   - ref: A SHA, branch, or tag.
    ///   - appID: Only runs from this GitHub App.
    public func runs(
        for ref: String, in owner: String, _ name: String, matching filter: CheckRunFilter = CheckRunFilter(), appID: Int? = nil,
        perPage: Int = 100
    ) -> Paginated<CheckRun> {
        client.paginate(
            .wrappedList(
                path(owner, name, "/commits/\(escapePath(ref))/check-runs"), key: "check_runs",
                query: filter.query + .query(("app_id", appID), ("per_page", perPage))))
    }

    /// The check runs in a suite. `GET /repos/{owner}/{repo}/check-suites/{check_suite_id}/check-runs`
    public func runs(
        inSuite suiteID: Int, in owner: String, _ name: String, matching filter: CheckRunFilter = CheckRunFilter(), perPage: Int = 100
    ) -> Paginated<CheckRun> {
        client.paginate(
            .wrappedList(
                path(owner, name, "/check-suites/\(suiteID)/check-runs"), key: "check_runs", query: filter.query + .query(("per_page", perPage))
            ))
    }

    // MARK: Check suites

    /// Creates a check suite for a commit, as a GitHub App whose suites aren't created on push.
    /// `POST /repos/{owner}/{repo}/check-suites`
    /// - Returns: The new suite, or the app's existing one for the commit.
    @discardableResult
    public func createSuite(headSHA: String, in owner: String, _ name: String) async throws(GitHubError) -> CheckSuite {
        try await client.value(GitHubRequest(.post, path(owner, name, "/check-suites"), body: ["head_sha": headSHA]))
    }

    /// One check suite. `GET /repos/{owner}/{repo}/check-suites/{check_suite_id}`
    public func suite(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> CheckSuite {
        try await client.value(GitHubRequest(.get, path(owner, name, "/check-suites/\(id)")))
    }

    /// The check suites on a commit. `GET /repos/{owner}/{repo}/commits/{ref}/check-suites`
    /// - Parameters:
    ///   - ref: A SHA, branch, or tag.
    ///   - appID: Only suites from this GitHub App.
    ///   - checkName: Only suites with a check run of this name.
    public func suites(
        for ref: String, in owner: String, _ name: String, appID: Int? = nil, checkName: String? = nil, perPage: Int = 100
    ) -> Paginated<CheckSuite> {
        client.paginate(
            .wrappedList(
                path(owner, name, "/commits/\(escapePath(ref))/check-suites"), key: "check_suites",
                query: .query(("app_id", appID), ("check_name", checkName), ("per_page", perPage))))
    }

    /// Asks the app that reported a check suite to run it again. `POST /repos/{owner}/{repo}/check-suites/{check_suite_id}/rerequest`
    public func rerequestSuite(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/check-suites/\(id)/rerequest")))
    }

    /// Chooses which apps' check suites GitHub creates on every push. `PATCH /repos/{owner}/{repo}/check-suites/preferences`
    @discardableResult
    public func setSuitePreferences(
        _ autoTrigger: [CheckSuitePreferences.AutoTrigger], in owner: String, _ name: String
    ) async throws(GitHubError) -> CheckSuitePreferences {
        struct Body: Encodable, Sendable {
            let autoTriggerChecks: [CheckSuitePreferences.AutoTrigger]
            enum CodingKeys: String, CodingKey { case autoTriggerChecks = "auto_trigger_checks" }
        }
        return try await client.value(
            GitHubRequest(.patch, path(owner, name, "/check-suites/preferences"), body: Body(autoTriggerChecks: autoTrigger)))
    }
}
