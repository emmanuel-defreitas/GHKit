import Foundation
import GHKit
import MCP

/// Pull requests, their diffs, reviews, and review comments.
///
/// A pull request's conversation, labels, and assignees use the issue tools.
enum PullRequestTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]
    static let pull: [String: MCP.Value] = ["number": Schema.integer("The pull request number.")]
    static let requiredPull = required + ["number"]

    static let states: KeyValuePairs<String, IssueStateFilter> = ["open": .open, "closed": .closed, "all": .all]
    static let sorts: KeyValuePairs<String, PullRequestSort> = [
        "created": .created, "updated": .updated, "popularity": .popularity, "long_running": .longRunning,
    ]
    static let methods: KeyValuePairs<String, MergeMethod> = ["merge": .merge, "squash": .squash, "rebase": .rebase]
    static let events: KeyValuePairs<String, ReviewEvent> = [
        "APPROVE": .approve, "REQUEST_CHANGES": .requestChanges, "COMMENT": .comment,
    ]
    static let sides: KeyValuePairs<String, DiffSide> = ["RIGHT": .right, "LEFT": .left]

    static func owner(_ arguments: ToolArguments) throws(ToolFailure) -> (String, String) {
        (try arguments.string("owner"), try arguments.string("repo"))
    }

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_pull_requests",
            title: "List pull requests",
            description: "A repository's pull requests, newest first.",
            schema: Schema.object(
                repository,
                [
                    "state": Schema.oneOf(states, "Defaults to `open`."),
                    "head": Schema.string("Only pull requests from this branch, as `owner:branch`."),
                    "base": Schema.string("Only pull requests into this branch."),
                    "sort": Schema.oneOf(sorts, "Defaults to `created`."),
                ],
                Schema.paging,
                required: required
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.list(
                owner, repo, state: arguments.choice("state", from: states) ?? .open, head: arguments.optionalString("head"),
                base: arguments.optionalString("base"), sort: arguments.choice("sort", from: sorts) ?? .created,
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_pull_request",
            title: "Get pull request",
            description: "One pull request: title, body, branches, head SHA, mergeability, review state, and counts.",
            schema: Schema.object(repository, pull, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(await context.client.pullRequests.pullRequest(arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "get_pull_request_diff",
            title: "Get pull request diff",
            description: "A pull request's changes as a unified diff. Use `list_pull_request_files` for a large one.",
            schema: Schema.object(repository, pull, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return .message(try await context.client.pullRequests.diff(arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "list_pull_request_files",
            title: "List changed files",
            description: "The files a pull request changes, with their status, line counts, and patches.",
            schema: Schema.object(repository, pull, Schema.paging, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.files(of: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_pull_request_commits",
            title: "List pull request commits",
            description: "A pull request's commits, oldest first.",
            schema: Schema.object(repository, pull, Schema.paging, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.commits(of: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_pull_request_reviews",
            title: "List reviews",
            description: "A pull request's reviews, oldest first: who reviewed, their verdict, and their summary.",
            schema: Schema.object(repository, pull, Schema.paging, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.reviews(of: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_review_comments",
            title: "List review comments",
            description: "Comments on a pull request's diff, oldest first, with their file, line, and reply thread.",
            schema: Schema.object(repository, pull, Schema.paging, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.reviewComments(
                on: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_requested_reviewers",
            title: "Get requested reviewers",
            description: "The people and teams asked to review a pull request who haven't reviewed yet.",
            schema: Schema.object(repository, pull, required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(await context.client.pullRequests.requestedReviewers(of: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "list_pull_requests_for_commit",
            title: "Find pull requests for a commit",
            description: "Pull requests that contain a commit: open ones that include it, or the merged one that introduced it.",
            schema: Schema.object(repository, ["sha": Schema.string("The commit SHA.")], Schema.paging, required: required + ["sha"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.pullRequests.pullRequests(
                containing: arguments.string("sha"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
    ]

    // MARK: Writing

    static let lineFields: [String: MCP.Value] = [
        "path": Schema.string("The file to comment on."),
        "line": Schema.integer("The line in the diff to comment on. Omit it to comment on the whole file."),
        "startLine": Schema.integer("The first line, for a comment on a range ending at `line`."),
        "side": Schema.oneOf(sides, "`RIGHT` for added or unchanged lines, `LEFT` for removed ones. Defaults to `RIGHT`."),
        "body": Schema.string("The comment, in Markdown."),
    ]

    static let writes: [GitHubTool] = [
        GitHubTool(
            "create_pull_request",
            title: "Create pull request",
            kind: .write,
            description: "Opens a pull request from `head` into `base`.",
            schema: Schema.object(
                repository,
                [
                    "title": Schema.string("The title."),
                    "head": Schema.string("The branch with the changes. Use `owner:branch` for a fork."),
                    "base": Schema.string("The branch to merge into."),
                    "body": Schema.string("The description, in Markdown."),
                    "draft": Schema.boolean("Whether to open it as a draft."),
                ],
                required: required + ["title", "head", "base"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let pullRequest = NewPullRequest(
                title: try arguments.string("title"), head: try arguments.string("head"), base: try arguments.string("base"),
                body: try arguments.optionalString("body"), isDraft: try arguments.optionalBool("draft"))
            return try .json(await context.client.pullRequests.create(pullRequest, in: owner, repo))
        },
        GitHubTool(
            "update_pull_request",
            title: "Update pull request",
            kind: .write,
            idempotent: true,
            description: "Changes a pull request's title, description, base branch, or open or closed state.",
            schema: Schema.object(
                repository, pull,
                [
                    "title": Schema.string("A new title."),
                    "body": Schema.string("A new description, in Markdown."),
                    "state": Schema.oneOf(["open", "closed"], "Close it without merging, or reopen it."),
                    "base": Schema.string("A new branch to merge into."),
                ],
                required: requiredPull
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let changes = PullRequestUpdate(
                title: try arguments.optionalString("title"),
                body: try arguments.optionalString("body"),
                state: try arguments.choice("state", from: ["open": IssueState.open, "closed": .closed]),
                base: try arguments.optionalString("base")
            )
            return try .json(await context.client.pullRequests.update(arguments.int("number"), in: owner, repo, changes))
        },
        GitHubTool(
            "merge_pull_request",
            title: "Merge pull request",
            kind: .write,
            description: "Merges a pull request now. Pass the head `sha` you reviewed so newer pushes aren't merged by accident.",
            schema: Schema.object(
                repository, pull,
                [
                    "method": Schema.oneOf(methods, "How to merge. Defaults to the repository's default."),
                    "commitTitle": Schema.string("The merge or squash commit's title."),
                    "commitMessage": Schema.string("The merge or squash commit's message."),
                    "sha": Schema.string("The head SHA the pull request must still have."),
                ],
                required: requiredPull
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let options = MergeOptions(
                method: try arguments.choice("method", from: methods),
                commitTitle: try arguments.optionalString("commitTitle"),
                commitMessage: try arguments.optionalString("commitMessage"),
                expectedHeadSHA: try arguments.optionalString("sha")
            )
            return try .json(await context.client.pullRequests.merge(arguments.int("number"), in: owner, repo, options))
        },
        GitHubTool(
            "update_pull_request_branch",
            title: "Update pull request branch",
            kind: .write,
            description: "Merges the base branch into the pull request's branch. GitHub finishes in the background.",
            schema: Schema.object(
                repository, pull, ["sha": Schema.string("The head SHA the branch must still have.")], required: requiredPull)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let number = try arguments.int("number")
            try await context.client.pullRequests.updateBranch(number, in: owner, repo, expectedHeadSHA: arguments.optionalString("sha"))
            return .message("GitHub is updating pull request #\(number)'s branch.")
        },
        GitHubTool(
            "request_reviewers",
            title: "Request reviewers",
            kind: .write,
            idempotent: true,
            description: "Asks people or teams to review a pull request.",
            schema: Schema.object(
                repository, pull,
                [
                    "reviewers": Schema.array(of: ["type": "string"], "Logins to ask."),
                    "teams": Schema.array(of: ["type": "string"], "Team slugs to ask."),
                ],
                required: requiredPull
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let (reviewers, teams) = (try arguments.strings("reviewers"), try arguments.strings("teams"))
            guard !reviewers.isEmpty || !teams.isEmpty else { throw ToolFailure("Pass `reviewers`, `teams`, or both.") }
            return try .json(
                await context.client.pullRequests.requestReviewers(reviewers, teams: teams, on: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "create_review",
            title: "Review pull request",
            kind: .write,
            description: """
                Reviews a pull request: approve, request changes, or comment, with optional line comments. \
                Without `event`, the review stays pending until submitted on GitHub.
                """,
            schema: Schema.object(
                repository, pull,
                [
                    "event": Schema.oneOf(events, "The verdict. Omit it to leave the review pending."),
                    "body": Schema.string("The review summary, in Markdown. Required for REQUEST_CHANGES and COMMENT."),
                    "commitID": Schema.string("The commit SHA to review. Defaults to the latest."),
                    "comments": Schema.array(
                        of: Schema.object(lineFields, required: ["path", "line", "body"]), "Comments on lines of the diff."),
                ],
                required: requiredPull
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let comments = try (arguments["comments"]?.arrayValue ?? []).map { item throws(ToolFailure) in
                guard let fields = item.objectValue else { throw ToolFailure("Each item in `comments` must be an object.") }
                let comment = ToolArguments(fields)
                return NewReview.Comment(
                    try comment.string("body"), path: try comment.string("path"),
                    at: try reviewLocation(comment) ?? .line(try comment.int("line")))
            }
            let review = NewReview(
                body: try arguments.optionalString("body"),
                event: try arguments.choice("event", from: events),
                commitID: try arguments.optionalString("commitID"),
                comments: comments
            )
            return try .json(await context.client.pullRequests.createReview(review, on: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "add_review_comment",
            title: "Comment on a line",
            kind: .write,
            description: "Comments on a line, a range of lines, or a whole file in a pull request's diff, outside a review.",
            schema: Schema.object(
                repository, pull, lineFields,
                ["commitID": Schema.string("The commit SHA to comment on. Defaults to the pull request's head.")],
                required: requiredPull + ["path", "body"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let number = try arguments.int("number")
            var commitID = try arguments.optionalString("commitID")
            if commitID == nil {
                // GitHub requires the commit, which models rarely know, so use the head.
                commitID = try await context.client.pullRequests.pullRequest(number, in: owner, repo).head.sha
            }
            let location: ReviewCommentLocation =
                switch try reviewLocation(arguments) {
                case .line(let line, let side)?: .line(line, side: side)
                case .lines(let start, let startSide, let end, let side)?: .lines(start: start, startSide: startSide, end: end, side: side)
                case .position(let position)?: .position(position)
                case nil: .file
                }
            let comment = NewReviewComment(try arguments.string("body"), path: try arguments.string("path"), at: location, commitID: commitID)
            return try .json(await context.client.pullRequests.createReviewComment(comment, on: number, in: owner, repo))
        },
        GitHubTool(
            "reply_to_review_comment",
            title: "Reply to review comment",
            kind: .write,
            description: "Replies in the thread of a top-level review comment.",
            schema: Schema.object(
                repository, pull,
                ["commentID": Schema.integer("The ID of the comment that started the thread."), "body": Schema.string("The reply, in Markdown.")],
                required: requiredPull + ["commentID", "body"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.pullRequests.replyToReviewComment(
                    id: arguments.int("commentID"), on: arguments.int("number"), in: owner, repo, body: arguments.string("body")))
        },
    ]

    /// `line`, `startLine`, and `side` as a place in the diff, or `nil` without a `line`.
    static func reviewLocation(_ arguments: ToolArguments) throws(ToolFailure) -> NewReview.Comment.Location? {
        guard let line = try arguments.optionalInt("line") else { return nil }
        let side = try arguments.choice("side", from: sides) ?? .right
        guard let start = try arguments.optionalInt("startLine"), start != line else { return .line(line, side: side) }
        guard start < line else { throw ToolFailure("`startLine` must come before `line`.") }
        return .lines(start: start, startSide: side, end: line, side: side)
    }
}
