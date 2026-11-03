import GHKit
import MCP

/// Projects: boards and tables of issues, pull requests, and drafts, with custom fields and status updates.
enum ProjectTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reads + writes
    }

    static let owner: [String: MCP.Value] = [
        "org": Schema.string("The organization that owns the project. Pass `org` or `user`."),
        "user": Schema.string("The user that owns the project. Pass `org` or `user`."),
    ]
    static let project: [String: MCP.Value] = owner.merging([
        "project": Schema.integer("The project's number, from its URL.", minimum: 1)
    ]) { _, new in new }
    static let fieldFilter: [String: MCP.Value] = [
        "fields": Schema.array(
            of: ["type": "integer"], "IDs of fields to include values for, from `list_project_fields`. Defaults to the title only.")
    ]

    static let statuses: KeyValuePairs<String, ProjectStatus> = [
        "on_track": .onTrack, "at_risk": .atRisk, "off_track": .offTrack, "complete": .complete, "inactive": .inactive,
    ]

    /// The projects API for the `org` or `user` argument.
    static func projects(_ arguments: ToolArguments, _ client: GitHubClient) throws(ToolFailure) -> ProjectsAPI {
        switch (try arguments.optionalString("org"), try arguments.optionalString("user")) {
        case (let org?, nil): client.projects(.organization(org))
        case (nil, let user?): client.projects(.user(user))
        default: throw ToolFailure("Pass `org` or `user`, not both.")
        }
    }

    static func fields(_ arguments: ToolArguments) throws(ToolFailure) -> [Int]? {
        let ids = try arguments.ints("fields")
        return ids.isEmpty ? nil : ids
    }

    /// The one field value given, as `text`, `number`, `date`, `optionID`, `iterationID`, or `clear`.
    static func fieldValue(_ arguments: ToolArguments) throws(ToolFailure) -> ProjectFieldValue {
        var values: [ProjectFieldValue] = []
        if let text = try arguments.optionalString("text") { values.append(.text(text)) }
        switch arguments["number"] {
        case nil: break
        case .int(let number)?: values.append(.number(Double(number)))
        case .double(let number)?: values.append(.number(number))
        case .string(let text)?:
            guard let number = Double(text) else { throw ToolFailure("`number` must be a number.") }
            values.append(.number(number))
        default: throw ToolFailure("`number` must be a number.")
        }
        if let date = try arguments.optionalCalendarDate("date") { values.append(.date(date)) }
        if let id = try arguments.optionalString("optionID") { values.append(.singleSelect(optionID: id)) }
        if let id = try arguments.optionalString("iterationID") { values.append(.iteration(id: id)) }
        if try arguments.bool("clear", default: false) { values.append(.clear) }
        guard values.count == 1, let value = values.first else {
            throw ToolFailure("Pass exactly one of `text`, `number`, `date`, `optionID`, `iterationID`, or `clear`.")
        }
        return value
    }

    // MARK: Reading

    static let reads: [GitHubTool] = [
        GitHubTool(
            "list_projects",
            title: "List projects",
            description: "An organization's or user's projects that the signed-in user can see.",
            schema: Schema.object(
                owner, ["query": Schema.string("Only projects that match, such as `roadmap` or `is:open`.")], Schema.paging)
        ) { arguments, context in
            let list = try projects(arguments, context.client).list(matching: arguments.optionalString("query"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_project",
            title: "Get project",
            description: "One project with its title, description, state, and latest status update.",
            schema: Schema.object(project, required: ["project"])
        ) { arguments, context in
            try .json(await projects(arguments, context.client).project(arguments.int("project")))
        },
        GitHubTool(
            "list_project_fields",
            title: "List project fields",
            description: """
                A project's fields, such as Status, Priority, or Iteration, with their IDs, types, and the IDs of \
                single-select options and iterations. Use these IDs with `update_project_item`.
                """,
            schema: Schema.object(project, Schema.paging, required: ["project"])
        ) { arguments, context in
            let list = try projects(arguments, context.client).fields(of: arguments.int("project"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_project_items",
            title: "List project items",
            description: """
                Items in a project: issues, pull requests, and drafts. Pass `fields` to include their values, and \
                `query` to filter with the same syntax as the project's filter bar.
                """,
            schema: Schema.object(
                project, fieldFilter,
                ["query": Schema.string("A filter such as `status:\"In progress\" assignee:@me`.")],
                Schema.paging,
                required: ["project"]
            )
        ) { arguments, context in
            let list = try projects(arguments, context.client).items(
                of: arguments.int("project"), matching: arguments.optionalString("query"), fields: fields(arguments),
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_project_item",
            title: "Get project item",
            description: "One item in a project and the issue, pull request, or draft it holds.",
            schema: Schema.object(
                project, fieldFilter, ["itemID": Schema.integer("The item's ID, from `list_project_items`.")],
                required: ["project", "itemID"])
        ) { arguments, context in
            try .json(
                await projects(arguments, context.client).item(
                    arguments.int("itemID"), of: arguments.int("project"), fields: fields(arguments)))
        },
        GitHubTool(
            "list_project_status_updates",
            title: "List project status updates",
            description: "A project's recent status updates, newest first.",
            schema: Schema.object(
                project, ["limit": Schema.integer("How many to return. Defaults to 20.", minimum: 1, maximum: 100)],
                required: ["project"])
        ) { arguments, context in
            let limit = min(max(try arguments.optionalInt("limit") ?? 20, 1), 100)
            return try .json(await projects(arguments, context.client).statusUpdates(of: arguments.int("project"), limit: limit))
        },
    ]

    // MARK: Writing

    static let writes: [GitHubTool] = [
        GitHubTool(
            "create_project",
            title: "Create project",
            kind: .write,
            description: "Creates an empty project owned by an organization or user.",
            schema: Schema.object(owner, ["title": Schema.string("The project's title.")], required: ["title"])
        ) { arguments, context in
            try .json(await projects(arguments, context.client).create(title: arguments.string("title")))
        },
        GitHubTool(
            "update_project",
            title: "Update project",
            kind: .write,
            idempotent: true,
            description: "Changes a project's title, description, README, or visibility, or closes or reopens it.",
            schema: Schema.object(
                project,
                [
                    "title": Schema.string("A new title."),
                    "shortDescription": Schema.string("A new one-line description."),
                    "readme": Schema.string("A new README, in Markdown."),
                    "public": Schema.boolean("Whether anyone can see the project."),
                    "closed": Schema.boolean("True to close the project, false to reopen it."),
                ],
                required: ["project"]
            )
        ) { arguments, context in
            let api = try projects(arguments, context.client)
            let number = try arguments.int("project")
            let (title, shortDescription) = (try arguments.optionalString("title"), try arguments.optionalText("shortDescription"))
            let (readme, isPublic) = (try arguments.optionalText("readme"), try arguments.optionalBool("public"))
            let closed = try arguments.optionalBool("closed")
            var result: Project?
            if title != nil || shortDescription != nil || readme != nil || isPublic != nil {
                result = try await api.update(number, title: title, shortDescription: shortDescription, readme: readme, isPublic: isPublic)
            }
            if let closed {
                result = try await closed ? api.close(number) : api.reopen(number)
            }
            guard let result else { throw ToolFailure("Pass at least one field to change.") }
            return try .json(result)
        },
        GitHubTool(
            "delete_project",
            title: "Delete project",
            kind: .destructive,
            idempotent: true,
            description: "Deletes a project and its drafts. The issues and pull requests in it aren't touched.",
            schema: Schema.object(project, required: ["project"])
        ) { arguments, context in
            let number = try arguments.int("project")
            try await projects(arguments, context.client).delete(number)
            return .message("Deleted project \(number).")
        },
        GitHubTool(
            "add_project_item",
            title: "Add project item",
            kind: .write,
            idempotent: true,
            description: "Adds an existing issue or pull request to a project.",
            schema: Schema.object(
                project,
                [
                    "type": Schema.oneOf(["issue", "pull_request"], "What to add."),
                    "owner": Schema.string("The account that owns the issue's repository."),
                    "repo": Schema.string("The issue's repository."),
                    "number": Schema.integer("The issue or pull request number."),
                ],
                required: ["project", "type", "owner", "repo", "number"]
            )
        ) { arguments, context in
            let (owner, repo, number) = (try arguments.string("owner"), try arguments.string("repo"), try arguments.int("number"))
            let content: ProjectItemContentReference
            switch try arguments.string("type") {
            case "issue": content = .issue(owner: owner, repository: repo, number: number)
            case "pull_request": content = .pullRequest(owner: owner, repository: repo, number: number)
            default: throw ToolFailure("`type` must be one of: issue, pull_request.")
            }
            return try .json(await projects(arguments, context.client).addItem(content, to: arguments.int("project")))
        },
        GitHubTool(
            "add_project_draft_issue",
            title: "Add project draft issue",
            kind: .write,
            description: "Creates a draft issue that lives only in the project.",
            schema: Schema.object(
                project, ["title": Schema.string("The draft's title."), "body": Schema.string("The draft's body, in Markdown.")],
                required: ["project", "title"])
        ) { arguments, context in
            try .json(
                await projects(arguments, context.client).addDraftIssue(
                    title: arguments.string("title"), body: arguments.optionalString("body"), to: arguments.int("project")))
        },
        GitHubTool(
            "update_project_item",
            title: "Update project item",
            kind: .write,
            idempotent: true,
            description: """
                Sets one field on a project item, such as its Status. Get field, option, and iteration IDs from \
                `list_project_fields`. Pass exactly one value.
                """,
            schema: Schema.object(
                project,
                [
                    "itemID": Schema.integer("The item's ID, from `list_project_items`."),
                    "fieldID": Schema.integer("The field's ID."),
                    "text": Schema.string("A text field's new value."),
                    "number": ["type": "number", "description": "A number field's new value."],
                    "date": Schema.date("A date field's new value, as `YYYY-MM-DD`."),
                    "optionID": Schema.string("A single-select option's ID."),
                    "iterationID": Schema.string("An iteration's ID."),
                    "clear": Schema.boolean("True to clear the field."),
                ],
                required: ["project", "itemID", "fieldID"]
            )
        ) { arguments, context in
            let value = try fieldValue(arguments)
            return try .json(
                await projects(arguments, context.client).updateItem(
                    arguments.int("itemID"), in: arguments.int("project"), field: arguments.int("fieldID"), to: value))
        },
        GitHubTool(
            "delete_project_item",
            title: "Delete project item",
            kind: .destructive,
            idempotent: true,
            description: "Removes an item from a project. The issue or pull request itself stays; a draft is deleted.",
            schema: Schema.object(project, ["itemID": Schema.integer("The item's ID.")], required: ["project", "itemID"])
        ) { arguments, context in
            let (item, number) = (try arguments.int("itemID"), try arguments.int("project"))
            try await projects(arguments, context.client).deleteItem(item, from: number)
            return .message("Removed item \(item) from project \(number).")
        },
        GitHubTool(
            "create_project_status_update",
            title: "Create project status update",
            kind: .write,
            description: "Posts a status update on a project, such as whether it's on track.",
            schema: Schema.object(
                project,
                [
                    "status": Schema.oneOf(statuses, "How the project is going."),
                    "body": Schema.string("The update, in Markdown."),
                    "startDate": Schema.date("When the work started, as `YYYY-MM-DD`."),
                    "targetDate": Schema.date("When it should finish, as `YYYY-MM-DD`."),
                ],
                required: ["project"]
            )
        ) { arguments, context in
            try .json(
                await projects(arguments, context.client).createStatusUpdate(
                    in: arguments.int("project"),
                    status: arguments.choice("status", from: statuses),
                    body: arguments.optionalString("body"),
                    startDate: arguments.optionalCalendarDate("startDate"),
                    targetDate: arguments.optionalCalendarDate("targetDate")))
        },
    ]
}
