import Foundation
import Testing

@testable import GHKitActions
@testable import GHKitCore

@Suite("Actions")
struct ActionsTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let workflow = try decoder.decode(Workflow.self, from: loadFixture("workflow"))
        #expect(workflow.state == .active)
        #expect(workflow.path == ".github/workflows/blank.yaml")

        let run = try decoder.decode(WorkflowRun.self, from: loadFixture("workflow-run"))
        #expect(run.status == .queued)
        #expect(run.conclusion == nil)
        #expect(run.displayTitle == "Update README.md")
        #expect(run.headCommit?.author?.name == "Octo Cat")
        #expect(run.referencedWorkflows?.last?.ref == nil)
        #expect(run.repository.fullName == "octocat/Hello-World")

        let usage = try decoder.decode(WorkflowUsage.self, from: loadFixture("workflow-usage"))
        #expect(usage.billable["MACOS"]?.totalMilliseconds == 240_000)
        let runUsage = try decoder.decode(WorkflowRunUsage.self, from: loadFixture("workflow-run-usage"))
        #expect(runUsage.runDurationMilliseconds == 500_000)
        #expect(runUsage.billable["WINDOWS"]?.jobRuns?.map(\.jobID) == [6, 7])

        let dispatch = try decoder.decode(WorkflowDispatch.self, from: loadFixture("workflow-dispatch-response"))
        #expect(dispatch.workflowRunID == 1)
    }

    @Test func workflowRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/actions/workflows": .fixture("workflow-paginated")
            case let route where route.hasSuffix("/timing"): .fixture("workflow-usage")
            case let route where route.hasSuffix("/dispatches"): .fixture("workflow-dispatch-response")
            case let route where route.hasPrefix("PUT "): .noContent()
            default: .fixture("workflow")
            }
        }
        let actions = makeClient(transport).actions
        #expect(try await actions.workflows("o", "r").collect().count == 2)
        _ = try await actions.workflow(161335, in: "o", "r")
        _ = try await actions.workflow("ci.yml", in: "o", "r")
        try await actions.disableWorkflow("ci.yml", in: "o", "r")
        try await actions.enableWorkflow(.id(7), in: "o", "r")
        let dispatch = try await actions.dispatchWorkflow("deploy.yml", in: "o", "r", ref: "main", inputs: ["env": "prod", "dry_run": true])
        #expect(dispatch?.workflowRunID == 1)
        try await actions.dispatchWorkflow("ci.yml", in: "o", "r", ref: "v1.0")
        _ = try await actions.workflowUsage("ci.yml", in: "o", "r")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/actions/workflows", "GET /repos/o/r/actions/workflows/161335", "GET /repos/o/r/actions/workflows/ci.yml",
                "PUT /repos/o/r/actions/workflows/ci.yml/disable", "PUT /repos/o/r/actions/workflows/7/enable",
                "POST /repos/o/r/actions/workflows/deploy.yml/dispatches", "POST /repos/o/r/actions/workflows/ci.yml/dispatches",
                "GET /repos/o/r/actions/workflows/ci.yml/timing",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(
            transport.requests[5].jsonBody == ["ref": "main", "inputs": ["env": "prod", "dry_run": true], "return_run_details": true])
        #expect(transport.requests[6].jsonBody == ["ref": "v1.0", "return_run_details": true])
    }

    @Test func dispatchWithoutRunDetails() async throws {
        let actions = makeClient(MockTransport(.noContent())).actions
        #expect(try await actions.dispatchWorkflow("ci.yml", in: "o", "r", ref: "main") == nil)
    }

    @Test func runRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/runs"): .fixture("workflow-run-paginated")
            case let route where route.hasSuffix("/timing"): .fixture("workflow-run-usage")
            case "DELETE /repos/o/r/actions/runs/30": .noContent()
            case let route where route.hasPrefix("POST "): .json("{}", status: 202)
            default: .fixture("workflow-run")
            }
        }
        let actions = makeClient(transport).actions
        #expect(try await actions.runs("o", "r").collect().count == 1)
        let filter = WorkflowRunFilter(
            actor: "mona", branch: "main", event: "push", state: .conclusion(.failure), created: ">=2024-01-01", headSHA: "abc",
            checkSuiteID: 42, excludesPullRequests: true)
        _ = try await actions.runs("o", "r", matching: filter, perPage: 10).firstPage()
        _ = try await actions.runs(of: "ci.yml", in: "o", "r", matching: WorkflowRunFilter(state: .status(.inProgress))).firstPage()
        _ = try await actions.run(id: 30, in: "o", "r")
        _ = try await actions.run(id: 30, attempt: 2, in: "o", "r", excludingPullRequests: true)
        try await actions.deleteRun(id: 30, in: "o", "r")
        try await actions.cancelRun(id: 30, in: "o", "r")
        try await actions.cancelRun(id: 30, in: "o", "r", force: true)
        try await actions.rerun(id: 30, in: "o", "r")
        try await actions.rerun(id: 30, in: "o", "r", failedJobsOnly: true, debugLogging: true)
        try await actions.approveRun(id: 30, in: "o", "r")
        _ = try await actions.runUsage(id: 30, in: "o", "r")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/actions/runs", "GET /repos/o/r/actions/runs", "GET /repos/o/r/actions/workflows/ci.yml/runs",
                "GET /repos/o/r/actions/runs/30", "GET /repos/o/r/actions/runs/30/attempts/2", "DELETE /repos/o/r/actions/runs/30",
                "POST /repos/o/r/actions/runs/30/cancel", "POST /repos/o/r/actions/runs/30/force-cancel", "POST /repos/o/r/actions/runs/30/rerun",
                "POST /repos/o/r/actions/runs/30/rerun-failed-jobs", "POST /repos/o/r/actions/runs/30/approve",
                "GET /repos/o/r/actions/runs/30/timing",
            ])
        #expect(
            transport.requests[1].queryItems == [
                "actor": "mona", "branch": "main", "event": "push", "status": "failure", "created": ">=2024-01-01", "head_sha": "abc",
                "check_suite_id": "42", "exclude_pull_requests": "true", "per_page": "10",
            ])
        #expect(transport.requests[2].queryItems == ["status": "in_progress", "per_page": "100"])
        #expect(transport.requests[3].queryItems == [:])
        #expect(transport.requests[4].queryItems == ["exclude_pull_requests": "true"])
        #expect(transport.requests[8].jsonBody == ["enable_debug_logging": false])
        #expect(transport.requests[9].jsonBody == ["enable_debug_logging": true])
    }

    @Test func requestsUseTheActionsDomain() async throws {
        let transport = MockTransport(.fixture("workflow"))
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), domains: [.actions: .token("ci")]))
        _ = try await github.actions.workflow("ci.yml", in: "o", "r")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer ci")
    }
}
