import Foundation
import GHKit
import MCP

/// Check runs and check suites: the CI results on a commit or pull request.
enum CheckTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reading + writing
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]

    static func repo(_ arguments: ToolArguments) throws(ToolFailure) -> (String, String) {
        (try arguments.string("owner"), try arguments.string("repo"))
    }

    static let refArgument = Schema.string("A commit SHA, branch, or tag. For a pull request, use its head SHA.")
    static let checkRunArgument: [String: MCP.Value] = ["check_run_id": Schema.integer("The check run's ID.")]

    static let statuses: KeyValuePairs<String, CheckStatus> = ["queued": .queued, "in_progress": .inProgress, "completed": .completed]

    // MARK: Reading

    static let reading: [GitHubTool] = [
        GitHubTool(
            "list_check_runs",
            title: "List check runs",
            description: """
                The checks on a commit, such as CI jobs and linters: name, status, conclusion, and summary. \
                Use it to see why a pull request's checks fail, then `list_check_run_annotations`.
                """,
            schema: Schema.object(
                repository,
                [
                    "ref": refArgument,
                    "name": Schema.string("Only checks with exactly this name."),
                    "status": Schema.oneOf(statuses, "Only checks with this status."),
                    "app_id": Schema.integer("Only checks from this GitHub App."),
                ],
                Schema.paging,
                required: required + ["ref"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let filter = CheckRunFilter(name: try arguments.optionalString("name"), status: try arguments.choice("status", from: statuses))
            let list = context.client.checks.runs(
                for: try arguments.string("ref"), in: owner, repo, matching: filter, appID: try arguments.optionalInt("app_id"),
                perPage: try arguments.perPage)
            let cursor = try arguments.cursor(for: context.client)
            let page = try await context.client.page(list.request, at: cursor)
            return try .json(ListPage(items: page.items.map(CheckRunSummary.init), nextCursor: page.next?.url.absoluteString))
        },
        GitHubTool(
            "get_check_run",
            title: "Get check run",
            description: "One check run, with its full output text and the app that reported it.",
            schema: Schema.object(repository, checkRunArgument, required: required + ["check_run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            return try .json(await context.client.checks.run(id: arguments.int("check_run_id"), in: owner, repo))
        },
        GitHubTool(
            "list_check_run_annotations",
            title: "List check run annotations",
            description: "The notes a check run left on lines of files, such as compiler errors and lint warnings.",
            schema: Schema.object(repository, checkRunArgument, Schema.paging, required: required + ["check_run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let list = context.client.checks.annotations(ofRun: try arguments.int("check_run_id"), in: owner, repo, perPage: try arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_check_suites",
            title: "List check suites",
            description: "The check suites on a commit, one per app, with their overall status and conclusion.",
            schema: Schema.object(
                repository,
                [
                    "ref": refArgument,
                    "app_id": Schema.integer("Only suites from this GitHub App."),
                    "check_name": Schema.string("Only suites with a check of this name."),
                ],
                Schema.paging,
                required: required + ["ref"]
            )
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let list = context.client.checks.suites(
                for: try arguments.string("ref"), in: owner, repo, appID: try arguments.optionalInt("app_id"),
                checkName: try arguments.optionalString("check_name"), perPage: try arguments.perPage)
            let cursor = try arguments.cursor(for: context.client)
            let page = try await context.client.page(list.request, at: cursor)
            return try .json(ListPage(items: page.items.map(CheckSuiteSummary.init), nextCursor: page.next?.url.absoluteString))
        },
    ]

    // MARK: Writing

    static let writing: [GitHubTool] = [
        GitHubTool(
            "rerequest_check_run",
            title: "Re-run check run",
            kind: .write,
            description: "Asks the app that reported a check run to run it again. For GitHub Actions jobs, use `rerun_workflow_job`.",
            schema: Schema.object(repository, checkRunArgument, required: required + ["check_run_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let id = try arguments.int("check_run_id")
            try await context.client.checks.rerequestRun(id: id, in: owner, repo)
            return .message("Asked for check run \(id) to run again.")
        },
        GitHubTool(
            "rerequest_check_suite",
            title: "Re-run check suite",
            kind: .write,
            description: "Asks the app that reported a check suite to run all of its checks again.",
            schema: Schema.object(
                repository, ["check_suite_id": Schema.integer("The check suite's ID.")], required: required + ["check_suite_id"])
        ) { arguments, context in
            let (owner, repo) = try repo(arguments)
            let id = try arguments.int("check_suite_id")
            try await context.client.checks.rerequestSuite(id: id, in: owner, repo)
            return .message("Asked for check suite \(id) to run again.")
        },
    ]
}

/// A check run for lists: its result and summary, without the app and pull request objects.
struct CheckRunSummary: Encodable {
    let id: Int
    let name: String
    let status: CheckStatus
    let conclusion: CheckConclusion?
    let app: String?
    let title: String?
    let summary: String?
    let annotationsCount: Int
    let startedAt: Date?
    let completedAt: Date?
    let url: URL?

    init(_ run: CheckRun) {
        id = run.id
        name = run.name
        status = run.status
        conclusion = run.conclusion
        app = run.app?.slug ?? run.app?.name
        title = run.output.title
        summary = run.output.summary
        annotationsCount = run.output.annotationsCount
        startedAt = run.startedAt
        completedAt = run.completedAt
        url = run.htmlURL ?? run.detailsURL
    }
}

/// A check suite for lists, without the repository and commit objects.
struct CheckSuiteSummary: Encodable {
    let id: Int
    let app: String?
    let status: CheckStatus?
    let conclusion: CheckConclusion?
    let branch: String?
    let sha: String
    let checkRunsCount: Int

    init(_ suite: CheckSuite) {
        id = suite.id
        app = suite.app?.slug ?? suite.app?.name
        status = suite.status
        conclusion = suite.conclusion
        branch = suite.headBranch
        sha = suite.headSHA
        checkRunsCount = suite.latestCheckRunsCount
    }
}
