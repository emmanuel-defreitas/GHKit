import GHKit
import MCP

/// Gists: list, read, create, update, and delete.
enum GistTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [
            GitHubTool(
                "list_gists",
                title: "List gists",
                description: "Gists, newest first: the signed-in user's, another user's, or the ones the signed-in user starred.",
                schema: Schema.object(
                    [
                        "user": Schema.string("A user's login, for their public gists."),
                        "starred": Schema.boolean("The signed-in user's starred gists instead."),
                        "since": Schema.date("Only gists updated at or after this time."),
                    ],
                    Schema.paging
                )
            ) { arguments, context in
                let collection: GistCollection
                switch (try arguments.optionalString("user"), try arguments.bool("starred", default: false)) {
                case (_?, true): throw ToolFailure("Pass `user` or `starred`, not both.")
                case (let user?, false): collection = .user(user)
                case (nil, true): collection = .starred
                case (nil, false): collection = .signedInUser
                }
                let list = try context.client.gists.list(collection, since: arguments.optionalDate("since"), perPage: arguments.perPage)
                return try await .page(list, arguments, context)
            },
            GitHubTool(
                "get_gist",
                title: "Get gist",
                description: "One gist with its files' contents, or an earlier revision of it.",
                schema: Schema.object(
                    [
                        "id": Schema.string("The gist ID."),
                        "revision": Schema.string("A revision's version SHA. Defaults to the latest."),
                    ],
                    required: ["id"]
                )
            ) { arguments, context in
                try .json(await context.client.gists.gist(id: arguments.string("id"), revision: arguments.optionalString("revision")))
            },
            GitHubTool(
                "create_gist",
                title: "Create gist",
                kind: .write,
                description: "Creates a gist as the signed-in user. Gists are secret unless `public` is true.",
                schema: Schema.object(
                    [
                        "files": Schema.anyObject("The files' contents by file name, such as {\"notes.md\": \"# Notes\"}."),
                        "description": Schema.string("A short description."),
                        "public": Schema.boolean("Whether anyone can find it. Defaults to false."),
                    ],
                    required: ["files"]
                )
            ) { arguments, context in
                let files = try (arguments.object("files") ?? [:]).mapValues { value throws(ToolFailure) in
                    guard let text = value.stringValue else { throw ToolFailure("Each file in `files` must be a string.") }
                    return text
                }
                guard !files.isEmpty else { throw ToolFailure("`files` needs at least one file.") }
                let gist = NewGist(
                    description: try arguments.optionalString("description"), files: files, isPublic: try arguments.optionalBool("public"))
                return try .json(await context.client.gists.create(gist))
            },
            GitHubTool(
                "update_gist",
                title: "Update gist",
                kind: .write,
                idempotent: true,
                description: "Changes a gist's description or files. Set a file to null to delete it. Files you leave out stay as they are.",
                schema: Schema.object(
                    [
                        "id": Schema.string("The gist ID."),
                        "description": Schema.string("A new description."),
                        "files": Schema.anyObject("New contents by file name, or null to delete a file."),
                    ],
                    required: ["id"]
                )
            ) { arguments, context in
                let files = try (arguments.object("files") ?? [:]).mapValues { value throws(ToolFailure) -> GistUpdate.FileChange in
                    if value.isNull { return .delete }
                    guard let text = value.stringValue else { throw ToolFailure("Each file in `files` must be a string or null.") }
                    return .content(text)
                }
                let update = GistUpdate(description: try arguments.optionalString("description"), files: files)
                return try .json(await context.client.gists.update(id: arguments.string("id"), update))
            },
            GitHubTool(
                "delete_gist",
                title: "Delete gist",
                kind: .destructive,
                idempotent: true,
                description: "Deletes a gist.",
                schema: Schema.object(["id": Schema.string("The gist ID.")], required: ["id"])
            ) { arguments, context in
                let id = try arguments.string("id")
                try await context.client.gists.delete(id: id)
                return .message("Deleted gist \(id).")
            },
        ]
    }
}
