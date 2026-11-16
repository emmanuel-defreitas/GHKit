import Foundation
import MCP
import Testing

@testable import GHKitActions
@testable import GHKitChecks
@testable import GHKitCore
@testable import GHKitMCP

@Suite("MCP Actions and checks tools")
struct ActionsAndCheckToolsTests {
    static let repo: [String: MCP.Value] = ["owner": "o", "repo": "r"]
    static let base = "/repos/o/r/actions"

    static func with(_ extra: [String: MCP.Value]) -> [String: MCP.Value] {
        repo.merging(extra) { _, new in new }
    }

    static let cases: [ToolRequestCase] = [
        // Actions: reading
        .init(
            tool: "list_workflows", arguments: repo, response: .fixture("workflow-paginated"), route: "GET \(base)/workflows",
            query: ["per_page": "30"]),
        .init(
            tool: "list_workflow_runs", arguments: with(["branch": "main", "status": "failure", "perPage": 5]),
            response: .fixture("workflow-run-paginated"), route: "GET \(base)/runs",
            query: ["branch": "main", "status": "failure", "exclude_pull_requests": "true", "per_page": "5"]),
        .init(
            tool: "list_workflow_runs", arguments: with(["workflow": "ci.yml", "event": "push"]), response: .fixture("workflow-run-paginated"),
            route: "GET \(base)/workflows/ci.yml/runs", query: ["event": "push", "exclude_pull_requests": "true", "per_page": "30"]),
        .init(
            tool: "list_workflow_runs", arguments: with(["workflow": "161335"]), response: .fixture("workflow-run-paginated"),
            route: "GET \(base)/workflows/161335/runs", query: ["exclude_pull_requests": "true", "per_page": "30"]),
        .init(tool: "get_workflow_run", arguments: with(["run_id": 30]), response: .fixture("workflow-run"), route: "GET \(base)/runs/30"),
        .init(
            tool: "get_workflow_run", arguments: with(["run_id": 30, "attempt": 2]), response: .fixture("workflow-run"),
            route: "GET \(base)/runs/30/attempts/2"),
        .init(
            tool: "list_workflow_jobs", arguments: with(["run_id": 30, "all_attempts": true]), response: .fixture("job-paginated"),
            route: "GET \(base)/runs/30/jobs", query: ["filter": "all", "per_page": "30"]),
        .init(
            tool: "list_workflow_jobs", arguments: with(["run_id": 30, "attempt": 1]), response: .fixture("job-paginated"),
            route: "GET \(base)/runs/30/attempts/1/jobs", query: ["per_page": "30"]),
        .init(
            tool: "get_job_logs", arguments: with(["job_id": 9]), response: MockResponse(body: Data("done".utf8)),
            route: "GET \(base)/jobs/9/logs"),
        .init(
            tool: "get_job_logs", arguments: with(["job_id": 9, "step": 3]), response: MockResponse(body: Data("done".utf8)),
            route: "GET \(base)/jobs/9/steps/3/logs"),
        .init(
            tool: "list_workflow_run_artifacts", arguments: with(["run_id": 30, "name": "dist"]), response: .fixture("artifact-paginated"),
            route: "GET \(base)/runs/30/artifacts", query: ["name": "dist", "per_page": "30"]),
        .init(
            tool: "list_pending_deployments", arguments: with(["run_id": 30]), response: .fixture("pending-deployment-items"),
            route: "GET \(base)/runs/30/pending_deployments"),
        // Actions: writing
        .init(
            tool: "run_workflow", arguments: with(["workflow": "deploy.yml", "ref": "main", "inputs": ["env": "prod", "dry_run": true]]),
            response: .fixture("workflow-dispatch-response"), route: "POST \(base)/workflows/deploy.yml/dispatches",
            body: ["ref": "main", "inputs": ["env": "prod", "dry_run": true], "return_run_details": true]),
        .init(
            tool: "rerun_workflow_run", arguments: with(["run_id": 30, "failed_jobs_only": true]), response: .json("{}", status: 201),
            route: "POST \(base)/runs/30/rerun-failed-jobs", body: ["enable_debug_logging": false]),
        .init(
            tool: "rerun_workflow_job", arguments: with(["job_id": 9]), response: .json("{}", status: 201), route: "POST \(base)/jobs/9/rerun",
            body: ["enable_debug_logging": false]),
        .init(
            tool: "cancel_workflow_run", arguments: with(["run_id": 30, "force": true]), response: .json("{}", status: 202),
            route: "POST \(base)/runs/30/force-cancel"),
        .init(
            tool: "approve_workflow_run", arguments: with(["run_id": 30]), response: .json("{}", status: 201),
            route: "POST \(base)/runs/30/approve"),
        .init(
            tool: "review_pending_deployments",
            arguments: with(["run_id": 30, "environment_ids": [7], "state": "approved", "comment": "Ship it"]),
            response: .fixture("deployment-items"), route: "POST \(base)/runs/30/pending_deployments",
            body: ["environment_ids": [7], "state": "approved", "comment": "Ship it"]),
        .init(
            tool: "enable_workflow", arguments: with(["workflow": "ci.yml"]), response: .noContent(),
            route: "PUT \(base)/workflows/ci.yml/enable"),
        .init(
            tool: "disable_workflow", arguments: with(["workflow": "7"]), response: .noContent(), route: "PUT \(base)/workflows/7/disable"),
        .init(tool: "delete_workflow_run", arguments: with(["run_id": 30]), response: .noContent(), route: "DELETE \(base)/runs/30"),
        // Checks
        .init(
            tool: "list_check_runs", arguments: with(["ref": "release/v1", "name": "lint", "status": "completed"]),
            response: .fixture("check-run-paginated"), route: "GET /repos/o/r/commits/release/v1/check-runs",
            query: ["check_name": "lint", "status": "completed", "per_page": "30"]),
        .init(
            tool: "get_check_run", arguments: with(["check_run_id": 4]), response: .fixture("check-run"), route: "GET /repos/o/r/check-runs/4"),
        .init(
            tool: "list_check_run_annotations", arguments: with(["check_run_id": 4]), response: .fixture("check-annotation-items"),
            route: "GET /repos/o/r/check-runs/4/annotations", query: ["per_page": "30"]),
        .init(
            tool: "list_check_suites", arguments: with(["ref": "abc", "app_id": 1]), response: .fixture("check-suite-paginated"),
            route: "GET /repos/o/r/commits/abc/check-suites", query: ["app_id": "1", "per_page": "30"]),
        .init(
            tool: "rerequest_check_run", arguments: with(["check_run_id": 4]), response: .json("{}", status: 201),
            route: "POST /repos/o/r/check-runs/4/rerequest"),
        .init(
            tool: "rerequest_check_suite", arguments: with(["check_suite_id": 5]), response: .json("{}", status: 201),
            route: "POST /repos/o/r/check-suites/5/rerequest"),
    ]

    @Test(arguments: cases) func toolsSendTheirRequests(_ test: ToolRequestCase) async throws {
        try await test.check()
    }

    @Test func coversEveryTool() {
        let tested = Set(Self.cases.map(\.tool))
        let tools = Set((ActionsTools.tools(for: .readWrite) + CheckTools.tools(for: .readWrite)).map(\.name))
        #expect(tools.subtracting(tested).isEmpty, "Untested: \(tools.subtracting(tested).sorted())")
    }

    @Test func logsKeepTheirLastLines() async throws {
        let log = (1...10).map { "line \($0)" }.joined(separator: "\n")
        let transport = MockTransport(MockResponse(body: Data(log.utf8)))
        let (text, isError) = try await callTool("get_job_logs", Self.with(["job_id": 9, "lines": 2]), on: transport)
        #expect(!isError)
        #expect(text == "[Showing the last 2 of 10 lines.]\nline 9\nline 10")
        let (whole, _) = try await callTool("get_job_logs", Self.with(["job_id": 9]), on: transport)
        #expect(whole == log)
    }

    @Test func runListsAreCompact() async throws {
        let (text, isError) = try await callTool(
            "list_workflow_runs", Self.repo, on: MockTransport(.fixture("workflow-run-paginated")))
        #expect(!isError)
        #expect(text.contains(#""title":"Update README.md""#))
        #expect(text.contains(#""actor":"octocat""#))
        #expect(!text.contains("head_repository"))
    }

    @Test func checkRunListsAreCompact() async throws {
        let (text, isError) = try await callTool(
            "list_check_runs", Self.with(["ref": "main"]), on: MockTransport(.fixture("check-run-paginated")))
        #expect(!isError)
        #expect(text.contains(#""conclusion":"neutral""#))
        #expect(text.contains(#""title":"Mighty Readme report""#))
        #expect(!text.contains("pull_requests"))
    }

    @Test func dispatchWithoutRunDetailsSaysItStarted() async throws {
        let (text, isError) = try await callTool(
            "run_workflow", Self.with(["workflow": "ci.yml", "ref": "main"]), on: MockTransport(.noContent()))
        #expect(!isError)
        #expect(text == "Started the workflow.")
    }

    @Test func reviewsNeedEnvironments() async throws {
        let transport = MockTransport(.fixture("deployment-items"))
        let (text, isError) = try await callTool(
            "review_pending_deployments", Self.with(["run_id": 30, "environment_ids": [], "state": "rejected", "comment": "No"]),
            on: transport)
        #expect(isError)
        #expect(text == "`environment_ids` needs at least one ID.")
        #expect(transport.requests.isEmpty)
    }

    @Test func readOnlyHidesWrites() {
        let toolbox = GitHubToolbox(client: makeClient(MockTransport(.noContent())), toolsets: [.actions, .checks], access: .readOnly)
        let names = Set(toolbox.tools.map(\.name))
        #expect(names.isSuperset(of: ["list_workflow_runs", "get_job_logs", "list_check_runs", "list_check_run_annotations"]))
        #expect(names.isDisjoint(with: ["run_workflow", "rerun_workflow_run", "cancel_workflow_run", "delete_workflow_run", "rerequest_check_run"]))
        #expect(GitHubToolset.named("actions") == .actions)
        #expect(GitHubToolset.named("checks") == .checks)
    }
}
