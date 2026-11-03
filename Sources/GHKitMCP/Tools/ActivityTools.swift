import GHKit
import MCP

/// Notifications, events, stars, and watching.
enum ActivityTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let repository = Schema.repository
    static let optionalRepository: [String: MCP.Value] = [
        "owner": Schema.string("With `repo`: only this repository's. The account that owns it."),
        "repo": Schema.string("With `owner`: only this repository's. The repository name."),
    ]

    /// `owner` and `repo` if both are given, `nil` if neither is.
    static func optionalOwner(_ arguments: ToolArguments) throws(ToolFailure) -> (String, String)? {
        switch (try arguments.optionalString("owner"), try arguments.optionalString("repo")) {
        case (let owner?, let repo?): return (owner, repo)
        case (nil, nil): return nil
        default: throw ToolFailure("Pass both `owner` and `repo`, or neither.")
        }
    }

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_notifications",
            title: "List notifications",
            description: """
                The signed-in user's notifications, newest first: unread ones unless `all` is true. Each has a thread \
                `id` for `mark_notification_done`, a `reason`, and the issue, pull request, or release it's about.
                """,
            schema: Schema.object(
                optionalRepository,
                [
                    "all": Schema.boolean("Include notifications already read. Defaults to false."),
                    "participating": Schema.boolean("Only ones where the user is directly involved. Defaults to false."),
                    "since": Schema.date("Only ones updated after this time."),
                ],
                Schema.paging
            )
        ) { arguments, context in
            let filter = NotificationFilter(
                includeRead: try arguments.bool("all", default: false),
                participatingOnly: try arguments.bool("participating", default: false),
                since: try arguments.optionalDate("since")
            )
            let activity = context.client.activity
            let perPage = try arguments.perPage
            if let (owner, repo) = try optionalOwner(arguments) {
                return try await .page(activity.notifications(in: owner, repo, matching: filter, perPage: perPage), arguments, context)
            }
            return try await .page(activity.notifications(matching: filter, perPage: perPage), arguments, context)
        },
        GitHubTool(
            "list_events",
            title: "List events",
            description: """
                Recent activity, newest first: pushes, pull requests, issues, comments, stars, and more. Pass one of \
                `user`, `org`, or `owner` with `repo`. With `received`, a user's feed of events from people and \
                repositories they follow. GitHub keeps 30 days of events.
                """,
            schema: Schema.object(
                optionalRepository,
                [
                    "user": Schema.string("A user's login, for what they did."),
                    "org": Schema.string("An organization's login, for its public events."),
                    "received": Schema.boolean("With `user`: events they received instead of ones they caused."),
                ],
                Schema.paging
            )
        ) { arguments, context in
            let source: EventSource
            switch (try optionalOwner(arguments), try arguments.optionalString("user"), try arguments.optionalString("org")) {
            case ((let owner, let repo)?, nil, nil): source = .repository(owner: owner, name: repo)
            case (nil, let user?, nil): source = try arguments.bool("received", default: false) ? .received(user) : .user(user)
            case (nil, nil, let org?): source = .organization(org)
            default: throw ToolFailure("Pass exactly one of `user`, `org`, or `owner` with `repo`.")
            }
            return try await .page(context.client.activity.events(source, perPage: arguments.perPage), arguments, context)
        },
        GitHubTool(
            "list_starred_repositories",
            title: "List starred repositories",
            description: "Repositories a user starred, most recently starred first. Defaults to the signed-in user.",
            schema: Schema.object(["user": Schema.string("A user's login. Defaults to the signed-in user.")], Schema.paging)
        ) { arguments, context in
            let list = try context.client.activity.starredRepositories(by: arguments.optionalString("user"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "mark_notifications_read",
            title: "Mark notifications read",
            kind: .write,
            idempotent: true,
            description: "Marks every notification as read, or only one repository's when you pass `owner` and `repo`.",
            schema: Schema.object(optionalRepository)
        ) { arguments, context in
            if let (owner, repo) = try optionalOwner(arguments) {
                try await context.client.activity.markNotificationsRead(in: owner, repo)
                return .message("Marked notifications in \(owner)/\(repo) as read.")
            }
            try await context.client.activity.markNotificationsRead()
            return .message("Marked all notifications as read.")
        },
        GitHubTool(
            "mark_notification_done",
            title: "Mark notification done",
            kind: .write,
            idempotent: true,
            description: "Marks one notification as done, which removes it from the inbox.",
            schema: Schema.object(["threadID": Schema.string("The notification's `id`.")], required: ["threadID"])
        ) { arguments, context in
            let id = try arguments.string("threadID")
            try await context.client.activity.markThreadDone(id: id)
            return .message("Marked notification \(id) as done.")
        },
        GitHubTool(
            "star_repository",
            title: "Star repository",
            kind: .write,
            idempotent: true,
            description: "Stars a repository as the signed-in user.",
            schema: Schema.object(repository, required: ["owner", "repo"])
        ) { arguments, context in
            let (owner, repo) = (try arguments.string("owner"), try arguments.string("repo"))
            try await context.client.activity.star(owner, repo)
            return .message("Starred \(owner)/\(repo).")
        },
        GitHubTool(
            "unstar_repository",
            title: "Unstar repository",
            kind: .write,
            idempotent: true,
            description: "Removes the signed-in user's star from a repository.",
            schema: Schema.object(repository, required: ["owner", "repo"])
        ) { arguments, context in
            let (owner, repo) = (try arguments.string("owner"), try arguments.string("repo"))
            try await context.client.activity.unstar(owner, repo)
            return .message("Unstarred \(owner)/\(repo).")
        },
    ]
}
