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

    @Test func jobAndArtifactModelsDecode() throws {
        let job = try decoder.decode(Job.self, from: loadFixture("job"))
        #expect(job.status == .completed)
        #expect(job.conclusion == .success)
        #expect(job.steps?.map(\.number) == [1, 2, 3, 4, 5, 6, 7, 8, 16, 17])
        #expect(job.labels == ["self-hosted", "foo", "bar"])
        #expect(job.createdAt == nil)

        let artifact = try decoder.decode(Artifact.self, from: loadFixture("artifact"))
        #expect(artifact.sizeInBytes == 556)
        #expect(!artifact.isExpired)
        #expect(artifact.workflowRun?.headBranch == "main")

        let reviews = try decoder.decode([DeploymentReview].self, from: loadFixture("environment-approvals-items"))
        #expect(reviews.first?.state == .approved)
        #expect(reviews.first?.environments.first?.name == "staging")

        let pending = try decoder.decode([PendingDeployment].self, from: loadFixture("pending-deployment-items"))
        #expect(pending.first?.environment.name == "staging")
        guard case .user(let user)? = pending.first?.reviewers.first, case .team(let team)? = pending.first?.reviewers.last else {
            Issue.record("Expected a user and a team reviewer")
            return
        }
        #expect(user.login == "octocat")
        #expect(team.slug == "justice-league")
    }

    @Test func jobAndLogRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/jobs"): .fixture("job-paginated")
            case let route where route.hasSuffix("/logs") && route.hasPrefix("GET /repos/o/r/actions/jobs"): .json("2024 Step 1\n")
            case let route where route.hasSuffix("/logs") && route.hasPrefix("GET "): MockResponse(body: Data("PK".utf8))
            case let route where route.hasPrefix("DELETE "): .noContent()
            case let route where route.hasSuffix("/rerun"): .json("{}", status: 201)
            default: .fixture("job")
            }
        }
        let actions = makeClient(transport).actions
        #expect(try await actions.jobs(ofRun: 30, in: "o", "r").collect().count == 1)
        _ = try await actions.jobs(ofRun: 30, in: "o", "r", includingEarlierAttempts: true, perPage: 5).firstPage()
        _ = try await actions.jobs(ofRun: 30, attempt: 2, in: "o", "r").firstPage()
        _ = try await actions.job(id: 9, in: "o", "r")
        try await actions.rerunJob(id: 9, in: "o", "r", debugLogging: true)
        #expect(try await actions.jobLogs(id: 9, in: "o", "r") == "2024 Step 1\n")
        _ = try await actions.stepLogs(2, ofJob: 9, in: "o", "r")
        #expect(try await actions.runLogs(id: 30, in: "o", "r") == Data("PK".utf8))
        _ = try await actions.runLogs(id: 30, attempt: 1, in: "o", "r")
        try await actions.deleteRunLogs(id: 30, in: "o", "r")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/actions/runs/30/jobs", "GET /repos/o/r/actions/runs/30/jobs", "GET /repos/o/r/actions/runs/30/attempts/2/jobs",
                "GET /repos/o/r/actions/jobs/9", "POST /repos/o/r/actions/jobs/9/rerun", "GET /repos/o/r/actions/jobs/9/logs",
                "GET /repos/o/r/actions/jobs/9/steps/2/logs", "GET /repos/o/r/actions/runs/30/logs",
                "GET /repos/o/r/actions/runs/30/attempts/1/logs", "DELETE /repos/o/r/actions/runs/30/logs",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[1].queryItems == ["filter": "all", "per_page": "5"])
        #expect(transport.requests[4].jsonBody == ["enable_debug_logging": true])
    }

    @Test func artifactRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/artifacts"): .fixture("artifact-paginated")
            case "GET /repos/o/r/actions/artifacts/11/zip": MockResponse(body: Data("PK".utf8))
            case "DELETE /repos/o/r/actions/artifacts/11": .noContent()
            default: .fixture("artifact")
            }
        }
        let actions = makeClient(transport).actions
        #expect(try await actions.artifacts("o", "r").collect().count == 2)
        _ = try await actions.artifacts("o", "r", named: "coverage").firstPage()
        _ = try await actions.artifacts(ofRun: 30, in: "o", "r", named: "dist", ascending: true).firstPage()
        _ = try await actions.artifact(id: 11, in: "o", "r")
        try await actions.deleteArtifact(id: 11, in: "o", "r")
        #expect(try await actions.downloadArtifact(id: 11, in: "o", "r") == Data("PK".utf8))

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/actions/artifacts", "GET /repos/o/r/actions/artifacts", "GET /repos/o/r/actions/runs/30/artifacts",
                "GET /repos/o/r/actions/artifacts/11", "DELETE /repos/o/r/actions/artifacts/11", "GET /repos/o/r/actions/artifacts/11/zip",
            ])
        #expect(transport.requests[1].queryItems == ["name": "coverage", "per_page": "100"])
        #expect(transport.requests[2].queryItems == ["name": "dist", "direction": "asc", "per_page": "100"])
    }

    @Test func deploymentReviewRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/actions/runs/30/approvals": .fixture("environment-approvals-items")
            case "GET /repos/o/r/actions/runs/30/pending_deployments": .fixture("pending-deployment-items")
            case "POST /repos/o/r/actions/runs/30/pending_deployments": .fixture("deployment-items")
            case "GET /repos/o/r/actions/runs/30/concurrency_groups": .fixture("concurrency-group-run-list")
            default: .noContent()
            }
        }
        let actions = makeClient(transport).actions
        #expect(try await actions.deploymentReviews(ofRun: 30, in: "o", "r").count == 1)
        #expect(try await actions.pendingDeployments(ofRun: 30, in: "o", "r").count == 1)
        let deployments = try await actions.reviewPendingDeployments(
            ofRun: 30, in: "o", "r", environmentIDs: [161_088_068], state: .approved, comment: "Ship it!")
        #expect(deployments.count == 1)
        try await actions.reviewDeploymentProtectionRule(ofRun: 30, in: "o", "r", environment: "prod", state: .rejected)
        try await actions.reviewDeploymentProtectionRule(ofRun: 30, in: "o", "r", environment: "prod", comment: "Still checking")
        let groups = try await actions.concurrencyGroups(ofRun: 30, in: "o", "r").collect()
        #expect(groups.first?.name == "deploy-prod")
        #expect(groups.first?.members.first?.position == 0)
        #expect(groups.first?.members.first?.status == .inProgress)

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/actions/runs/30/approvals", "GET /repos/o/r/actions/runs/30/pending_deployments",
                "POST /repos/o/r/actions/runs/30/pending_deployments", "POST /repos/o/r/actions/runs/30/deployment_protection_rule",
                "POST /repos/o/r/actions/runs/30/deployment_protection_rule", "GET /repos/o/r/actions/runs/30/concurrency_groups",
            ])
        #expect(transport.requests[2].jsonBody == ["environment_ids": [161_088_068], "state": "approved", "comment": "Ship it!"])
        #expect(transport.requests[3].jsonBody == ["environment_name": "prod", "state": "rejected"])
        #expect(transport.requests[4].jsonBody == ["environment_name": "prod", "comment": "Still checking"])
    }
}
