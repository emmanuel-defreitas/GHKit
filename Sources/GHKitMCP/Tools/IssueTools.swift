import Foundation
import GHKit
import MCP

/// Issues, their comments, labels, assignees, milestones, and sub-issues.
///
/// Pull requests are issues too, so the comment, label, and assignee tools also work on them.
enum IssueTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]
    static let issue: [String: MCP.Value] = ["number": Schema.integer("The issue or pull request number.")]
    static let requiredIssue = required + ["number"]

    static let states: KeyValuePairs<String, IssueStateFilter> = ["open": .open, "closed": .closed, "all": .all]
    static let sorts: KeyValuePairs<String, IssueSort> = ["created": .created, "updated": .updated, "comments": .comments]
    static let relationships: KeyValuePairs<String, IssueRelationship> = [
        "assigned": .assigned, "created": .created, "mentioned": .mentioned, "subscribed": .subscribed, "all": .all,
    ]
    static let closeReasons: KeyValuePairs<String, IssueStateReason> = [
        "completed": .completed, "not_planned": .notPlanned, "duplicate": .duplicate,
    ]

    static func owner(_ arguments: ToolArguments) throws(ToolFailure) -> (String, String) {
        (try arguments.string("owner"), try arguments.string("repo"))
    }

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_issues",
            title: "List issues",
            description: """
                Issues in a repository when you pass `owner` and `repo`, newest first. Without them, issues across \
                repositories that involve the signed-in user, optionally in one `org`. A repository's list also \
                includes pull requests; they have a `pull_request` field. Use `search_issues` for full-text search.
                """,
            schema: Schema.object(
                repository,
                [
                    "org": Schema.string("Without `owner` and `repo`: only issues in this organization."),
                    "relationship": Schema.oneOf(
                        relationships, "Without `owner` and `repo`: how the signed-in user is involved. Defaults to `assigned`."),
                    "state": Schema.oneOf(states, "Defaults to `open`."),
                    "labels": Schema.array(of: ["type": "string"], "Only issues with every one of these labels."),
                    "assignee": Schema.string("A login, `*` for any assignee, or `none` for unassigned. Repository only."),
                    "creator": Schema.string("Only issues opened by this login. Repository only."),
                    "mentioned": Schema.string("Only issues that mention this login. Repository only."),
                    "milestone": Schema.string("A milestone number, `*` for any, or `none`. Repository only."),
                    "since": Schema.date("Only issues updated at or after this time."),
                    "sort": Schema.oneOf(sorts, "Defaults to `created`."),
                ],
                Schema.paging
            )
        ) { arguments, context in
            let base = IssueFilter(
                state: try arguments.choice("state", from: states) ?? .open,
                labels: try arguments.strings("labels"),
                updatedSince: try arguments.optionalDate("since")
            )
            let sort = try arguments.choice("sort", from: sorts) ?? .created
            let issues = context.client.issues
            if let owner = try arguments.optionalString("owner") {
                var filter = base
                filter.assignee = try arguments.optionalString("assignee").map(assignee)
                filter.milestone = try arguments.optionalString("milestone").map(milestone)
                filter.creator = try arguments.optionalString("creator")
                filter.mentioned = try arguments.optionalString("mentioned")
                let list = try issues.list(owner, arguments.string("repo"), matching: filter, sort: sort, perPage: arguments.perPage)
                return try await .page(list, arguments, context)
            }
            let scope: IssueScope = try arguments.optionalString("org").map { .organization($0) } ?? .everywhere
            let list = try issues.list(
                arguments.choice("relationship", from: relationships) ?? .assigned, in: scope, matching: base, sort: sort,
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_issue",
            title: "Get issue",
            description: "One issue or pull request: title, body, state, labels, assignees, milestone, and counts.",
            schema: Schema.object(repository, issue, required: requiredIssue)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(await context.client.issues.issue(arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "list_issue_comments",
            title: "List issue comments",
            description: "The conversation on an issue or pull request, oldest first. Review comments on code aren't included.",
            schema: Schema.object(
                repository, issue, ["since": Schema.date("Only comments updated at or after this time.")], Schema.paging,
                required: requiredIssue)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.issues.comments(
                on: arguments.int("number"), in: owner, repo, updatedSince: arguments.optionalDate("since"),
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_issue_timeline",
            title: "Get issue timeline",
            description: """
                Everything that happened on an issue or pull request, oldest first: comments, commits, reviews, \
                labels, assignments, cross-references, and state changes.
                """,
            schema: Schema.object(repository, issue, Schema.paging, required: requiredIssue)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.issues.timeline(of: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_sub_issues",
            title: "List sub-issues",
            description: "An issue's sub-issues, in their order.",
            schema: Schema.object(repository, issue, Schema.paging, required: requiredIssue)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.issues.subIssues(of: arguments.int("number"), in: owner, repo, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_labels",
            title: "List labels",
            description: "A repository's labels, with their colors and descriptions.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try await .page(context.client.issues.labels(owner, repo, perPage: arguments.perPage), arguments, context)
        },
        GitHubTool(
            "list_milestones",
            title: "List milestones",
            description: "A repository's milestones, soonest due first, with their open and closed issue counts.",
            schema: Schema.object(repository, ["state": Schema.oneOf(states, "Defaults to `open`.")], Schema.paging, required: required)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let list = try context.client.issues.milestones(
                owner, repo, state: arguments.choice("state", from: states) ?? .open, perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_assignees",
            title: "List assignable users",
            description: "The people who can be assigned to issues in a repository.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try await .page(context.client.issues.assignees(owner, repo, perPage: arguments.perPage), arguments, context)
        },
        GitHubTool(
            "list_issue_types",
            title: "List issue types",
            description: "The issue types, such as Bug or Feature, that issues in a repository can have.",
            schema: Schema.object(repository, required: required)
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(await context.client.issues.types(owner, repo))
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "create_issue",
            title: "Create issue",
            kind: .write,
            description: "Opens an issue.",
            schema: Schema.object(
                repository,
                [
                    "title": Schema.string("The issue title."),
                    "body": Schema.string("The description, in Markdown."),
                    "labels": Schema.array(of: ["type": "string"], "Label names."),
                    "assignees": Schema.array(of: ["type": "string"], "Logins to assign, up to 10."),
                    "milestone": Schema.integer("A milestone number."),
                    "type": Schema.string("An issue type name, such as `Bug`. See `list_issue_types`."),
                ],
                required: required + ["title"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let issue = NewIssue(
                title: try arguments.string("title"),
                body: try arguments.optionalString("body"),
                assignees: try arguments.strings("assignees"),
                milestone: try arguments.optionalInt("milestone"),
                labels: try arguments.strings("labels"),
                type: try arguments.optionalString("type")
            )
            return try .json(await context.client.issues.create(issue, in: owner, repo))
        },
        GitHubTool(
            "update_issue",
            title: "Update issue",
            kind: .write,
            idempotent: true,
            description: """
                Changes an issue or pull request: title, body, open or closed, labels, assignees, or milestone. \
                `labels` and `assignees` replace the current ones; use `add_labels` or `add_assignees` to keep them.
                """,
            schema: Schema.object(
                repository, issue,
                [
                    "title": Schema.string("A new title."),
                    "body": Schema.string("A new description, in Markdown."),
                    "state": Schema.oneOf(["open", "closed"], "Open or close it."),
                    "stateReason": Schema.oneOf(closeReasons, "Why it's closed. Defaults to `completed` when closing."),
                    "labels": Schema.array(of: ["type": "string"], "Every label it should have."),
                    "assignees": Schema.array(of: ["type": "string"], "Everyone it should be assigned to."),
                    "milestone": Schema.integer("A milestone number."),
                    "removeMilestone": Schema.boolean("Set to true to clear the milestone."),
                ],
                required: requiredIssue
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            var milestone: IssueUpdate.Change<Int>? = try arguments.optionalInt("milestone").map { .set($0) }
            if try arguments.bool("removeMilestone", default: false) { milestone = .remove }
            let changes = IssueUpdate(
                title: try arguments.optionalString("title"),
                body: try arguments.optionalString("body"),
                state: try arguments.choice("state", from: ["open": IssueState.open, "closed": .closed]),
                stateReason: try arguments.choice("stateReason", from: closeReasons),
                assignees: try arguments.optionalStrings("assignees"),
                labels: try arguments.optionalStrings("labels"),
                milestone: milestone
            )
            return try .json(await context.client.issues.update(arguments.int("number"), in: owner, repo, changes))
        },
        GitHubTool(
            "add_issue_comment",
            title: "Comment on issue",
            kind: .write,
            description: "Adds a comment to an issue or pull request conversation.",
            schema: Schema.object(repository, issue, ["body": Schema.string("The comment, in Markdown.")], required: requiredIssue + ["body"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.issues.createComment(arguments.string("body"), on: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "update_issue_comment",
            title: "Edit issue comment",
            kind: .write,
            idempotent: true,
            description: "Replaces the text of an issue or pull request comment.",
            schema: Schema.object(
                repository, ["commentID": Schema.integer("The comment's ID."), "body": Schema.string("The new text, in Markdown.")],
                required: required + ["commentID", "body"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.issues.updateComment(id: arguments.int("commentID"), in: owner, repo, body: arguments.string("body")))
        },
        GitHubTool(
            "delete_issue_comment",
            title: "Delete issue comment",
            kind: .destructive,
            idempotent: true,
            description: "Deletes an issue or pull request comment.",
            schema: Schema.object(repository, ["commentID": Schema.integer("The comment's ID.")], required: required + ["commentID"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let id = try arguments.int("commentID")
            try await context.client.issues.deleteComment(id: id, in: owner, repo)
            return .message("Deleted comment \(id).")
        },
        GitHubTool(
            "add_labels",
            title: "Add labels",
            kind: .write,
            idempotent: true,
            description: "Adds labels to an issue or pull request, keeping the current ones. Returns every label it now has.",
            schema: Schema.object(
                repository, issue, ["labels": Schema.array(of: ["type": "string"], "Label names to add.")],
                required: requiredIssue + ["labels"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(await context.client.issues.addLabels(arguments.strings("labels"), to: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "remove_label",
            title: "Remove label",
            kind: .write,
            idempotent: true,
            description: "Removes one label from an issue or pull request. Returns the labels left.",
            schema: Schema.object(repository, issue, ["label": Schema.string("The label name.")], required: requiredIssue + ["label"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.issues.removeLabel(named: arguments.string("label"), from: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "add_assignees",
            title: "Add assignees",
            kind: .write,
            idempotent: true,
            description: "Assigns people to an issue or pull request, keeping the current assignees. An issue has at most 10.",
            schema: Schema.object(
                repository, issue, ["assignees": Schema.array(of: ["type": "string"], "Logins to assign.")],
                required: requiredIssue + ["assignees"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.issues.addAssignees(arguments.strings("assignees"), to: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "remove_assignees",
            title: "Remove assignees",
            kind: .write,
            idempotent: true,
            description: "Unassigns people from an issue or pull request.",
            schema: Schema.object(
                repository, issue, ["assignees": Schema.array(of: ["type": "string"], "Logins to unassign.")],
                required: requiredIssue + ["assignees"])
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            return try .json(
                await context.client.issues.removeAssignees(arguments.strings("assignees"), from: arguments.int("number"), in: owner, repo))
        },
        GitHubTool(
            "create_label",
            title: "Create label",
            kind: .write,
            description: "Creates a label in a repository.",
            schema: Schema.object(
                repository,
                [
                    "name": Schema.string("The label name."),
                    "color": Schema.string("A hex color without `#`, such as `f29513`."),
                    "description": Schema.string("A short description."),
                ],
                required: required + ["name"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            let label = NewLabel(
                name: try arguments.string("name"), color: try arguments.optionalString("color"),
                description: try arguments.optionalString("description"))
            return try .json(await context.client.issues.createLabel(label, in: owner, repo))
        },
        GitHubTool(
            "add_sub_issue",
            title: "Add sub-issue",
            kind: .write,
            description: "Makes one issue a sub-issue of another in the same repository.",
            schema: Schema.object(
                repository, issue,
                [
                    "subIssue": Schema.integer("The number of the issue to add under `number`."),
                    "replaceParent": Schema.boolean("Move it here if it already has another parent. Defaults to false."),
                ],
                required: requiredIssue + ["subIssue"]
            )
        ) { arguments, context in
            let (owner, repo) = try owner(arguments)
            // GitHub wants the sub-issue's ID, which models rarely know, so look it up by number.
            let child = try await context.client.issues.issue(arguments.int("subIssue"), in: owner, repo)
            return try .json(
                await context.client.issues.addSubIssue(
                    id: child.id, to: arguments.int("number"), in: owner, repo,
                    replaceParent: arguments.bool("replaceParent", default: false)))
        },
    ]

    // MARK: Filters

    static func assignee(_ text: String) -> IssueFilter.Assignee {
        switch text {
        case "*": .anyone
        case "none": .unassigned
        default: .user(text)
        }
    }

    static func milestone(_ text: String) throws(ToolFailure) -> IssueFilter.MilestoneFilter {
        switch text {
        case "*": return .any
        case "none": return .noMilestone
        default:
            guard let number = Int(text) else { throw ToolFailure("`milestone` must be a number, `*`, or `none`.") }
            return .number(number)
        }
    }
}
