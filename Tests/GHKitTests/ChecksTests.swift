import Foundation
import Testing

@testable import GHKitChecks
@testable import GHKitCore

@Suite("Checks")
struct ChecksTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let run = try decoder.decode(CheckRun.self, from: loadFixture("check-run"))
        #expect(run.status == .completed)
        #expect(run.conclusion == .neutral)
        #expect(run.output.annotationsCount == 2)
        #expect(run.checkSuite?.id == 5)
        #expect(run.pullRequests.first?.head.repository.name == "hello-world")
        _ = try decoder.decode(CheckRun.self, from: loadFixture("check-run-example-of-completed-conclusion"))

        let annotations = try decoder.decode([CheckAnnotation].self, from: loadFixture("check-annotation-items"))
        #expect(annotations.first?.level == .warning)
        #expect(annotations.first?.path == "README.md")

        let suite = try decoder.decode(CheckSuite.self, from: loadFixture("check-suite"))
        #expect(suite.conclusion == .neutral)
        #expect(suite.latestCheckRunsCount == 1)
        #expect(suite.headCommit.author?.name == "The Octocat")

        let preferences = try decoder.decode(CheckSuitePreferences.self, from: loadFixture("check-suite-preference"))
        #expect(preferences.autoTrigger.map(\.isEnabled) == [true, false])
    }

    @Test func checkRunRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/annotations"): .fixture("check-annotation-items")
            case let route where route.hasSuffix("/check-runs") && route.hasPrefix("GET "): .fixture("check-run-paginated")
            case let route where route.hasSuffix("/rerequest"): .json("{}", status: 201)
            case "POST /repos/o/r/check-runs": .fixture("check-run", status: 201)
            default: .fixture("check-run")
            }
        }
        let checks = makeClient(transport).checks
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let output = NewCheckRunOutput(
            title: "Lint", summary: "1 warning",
            annotations: [NewCheckAnnotation(path: "README.md", lines: 2...2, columns: 1...5, level: .warning, message: "Typo")],
            images: [NewCheckRunOutput.Image(alt: "Graph", url: URL(string: "https://example.com/graph.png")!)])
        _ = try await checks.createRun(
            NewCheckRun(
                name: "lint", headSHA: "abc", status: .inProgress, startedAt: started, output: output,
                actions: [CheckRunAction(label: "Fix", description: "Apply fixes", identifier: "fix")], externalID: "42"),
            in: "o", "r")
        _ = try await checks.createRun(NewCheckRun(name: "build", headSHA: "abc"), in: "o", "r")
        _ = try await checks.run(id: 4, in: "o", "r")
        _ = try await checks.updateRun(id: 4, in: "o", "r", CheckRunUpdate(conclusion: .success, completedAt: started, actions: []))
        #expect(try await checks.annotations(ofRun: 4, in: "o", "r").collect().count == 1)
        try await checks.rerequestRun(id: 4, in: "o", "r")
        #expect(try await checks.runs(for: "release/v1", in: "o", "r").collect().count == 1)
        _ = try await checks.runs(
            for: "abc", in: "o", "r", matching: CheckRunFilter(name: "lint", status: .completed, includesEarlierRuns: true), appID: 7,
            perPage: 10
        ).firstPage()
        _ = try await checks.runs(inSuite: 5, in: "o", "r").firstPage()

        #expect(
            transport.requests.map(\.route) == [
                "POST /repos/o/r/check-runs", "POST /repos/o/r/check-runs", "GET /repos/o/r/check-runs/4", "PATCH /repos/o/r/check-runs/4",
                "GET /repos/o/r/check-runs/4/annotations", "POST /repos/o/r/check-runs/4/rerequest",
                "GET /repos/o/r/commits/release/v1/check-runs", "GET /repos/o/r/commits/abc/check-runs",
                "GET /repos/o/r/check-suites/5/check-runs",
            ])
        #expect(
            transport.requests[0].jsonBody == [
                "name": "lint", "head_sha": "abc", "status": "in_progress", "started_at": "2023-11-14T22:13:20Z", "external_id": "42",
                "output": [
                    "title": "Lint", "summary": "1 warning",
                    "annotations": [
                        [
                            "path": "README.md", "start_line": 2, "end_line": 2, "start_column": 1, "end_column": 5,
                            "annotation_level": "warning", "message": "Typo",
                        ]
                    ],
                    "images": [["alt": "Graph", "image_url": "https://example.com/graph.png"]],
                ],
                "actions": [["label": "Fix", "description": "Apply fixes", "identifier": "fix"]],
            ])
        #expect(transport.requests[1].jsonBody == ["name": "build", "head_sha": "abc"])
        #expect(transport.requests[3].jsonBody == ["conclusion": "success", "completed_at": "2023-11-14T22:13:20Z", "actions": []])
        #expect(transport.requests[6].queryItems == ["per_page": "100"])
        #expect(
            transport.requests[7].queryItems == [
                "check_name": "lint", "status": "completed", "filter": "all", "app_id": "7", "per_page": "10",
            ])
    }

    @Test func checkSuiteRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/check-suites") && route.hasPrefix("GET "): .fixture("check-suite-paginated")
            case "PATCH /repos/o/r/check-suites/preferences": .fixture("check-suite-preference")
            case let route where route.hasSuffix("/rerequest"): .json("{}", status: 201)
            default: .fixture("check-suite")
            }
        }
        let checks = makeClient(transport).checks
        _ = try await checks.createSuite(headSHA: "abc", in: "o", "r")
        _ = try await checks.suite(id: 5, in: "o", "r")
        #expect(try await checks.suites(for: "main", in: "o", "r", appID: 1, checkName: "lint").collect().count == 1)
        try await checks.rerequestSuite(id: 5, in: "o", "r")
        let preferences = try await checks.setSuitePreferences([.init(appID: 4, isEnabled: false)], in: "o", "r")
        #expect(preferences.autoTrigger.count == 2)

        #expect(
            transport.requests.map(\.route) == [
                "POST /repos/o/r/check-suites", "GET /repos/o/r/check-suites/5", "GET /repos/o/r/commits/main/check-suites",
                "POST /repos/o/r/check-suites/5/rerequest", "PATCH /repos/o/r/check-suites/preferences",
            ])
        #expect(transport.requests[0].jsonBody == ["head_sha": "abc"])
        #expect(transport.requests[2].queryItems == ["app_id": "1", "check_name": "lint", "per_page": "100"])
        #expect(transport.requests[4].jsonBody == ["auto_trigger_checks": [["app_id": 4, "setting": false]]])
    }

    @Test func requestsUseTheChecksDomain() async throws {
        let transport = MockTransport(.fixture("check-run"))
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), domains: [.checks: .token("app")]))
        _ = try await github.checks.run(id: 4, in: "o", "r")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer app")
    }
}
