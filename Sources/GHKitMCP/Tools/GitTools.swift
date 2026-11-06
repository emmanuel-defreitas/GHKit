import Foundation
import GHKit
import MCP

/// Git objects and references: read trees and blobs, and build commits without a clone.
enum GitTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        reading + writing
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]

    static func git(_ arguments: ToolArguments, _ context: GitHubTool.Context) throws(ToolFailure) -> GitDatabaseAPI {
        context.client.repositories.git(try arguments.string("owner"), try arguments.string("repo"))
    }

    static let modes: KeyValuePairs<String, GitFileMode> = [
        "file": .file, "executable": .executable, "directory": .directory, "submodule": .submodule, "symlink": .symlink,
    ]

    // MARK: Reading

    static let reading: [GitHubTool] = [
        GitHubTool(
            "get_git_tree",
            title: "Get Git tree",
            description: """
                The entries of a tree: each path's mode, type, SHA, and size. With `recursive`, every file in the \
                repository at once; `truncated` says when GitHub stopped early.
                """,
            schema: Schema.object(
                repository,
                [
                    "sha": Schema.string("A tree SHA, or a branch or tag name."),
                    "recursive": Schema.boolean("List every level, not just the top one. Defaults to false."),
                ],
                required: required + ["sha"]
            )
        ) { arguments, context in
            try .json(await git(arguments, context).tree(arguments.string("sha"), recursive: arguments.bool("recursive", default: false)))
        },
        GitHubTool(
            "get_git_blob",
            title: "Get Git blob",
            description: "A blob's content by SHA, as text when it's UTF-8. Use it for files `get_git_tree` lists.",
            schema: Schema.object(repository, ["sha": Schema.string("The blob SHA.")], required: required + ["sha"])
        ) { arguments, context in
            try .json(BlobView(await git(arguments, context).blob(arguments.string("sha"))))
        },
        GitHubTool(
            "get_git_commit",
            title: "Get Git commit",
            description: "A commit object: message, author, committer, tree SHA, and parent SHAs. `get_commit` adds the changed files.",
            schema: Schema.object(repository, ["sha": Schema.string("The commit SHA.")], required: required + ["sha"])
        ) { arguments, context in
            try .json(await git(arguments, context).commit(arguments.string("sha")))
        },
        GitHubTool(
            "get_git_ref",
            title: "Get Git reference",
            description: "The object a branch or tag points to.",
            schema: Schema.object(
                repository, ["ref": Schema.string("Such as `heads/main` or `tags/v1.0`.")], required: required + ["ref"])
        ) { arguments, context in
            try .json(await git(arguments, context).ref(arguments.string("ref")))
        },
        GitHubTool(
            "list_git_refs",
            title: "List Git references",
            description: "Branches and tags whose names start with `prefix`, such as `heads/feature` or `tags/v1`.",
            schema: Schema.object(
                repository, ["prefix": Schema.string("Such as `heads`, `tags`, or `heads/release`.")], Schema.paging,
                required: required + ["prefix"])
        ) { arguments, context in
            try await .page(git(arguments, context).matchingRefs(arguments.string("prefix")), arguments, context)
        },
        GitHubTool(
            "get_git_tag",
            title: "Get Git tag",
            description: "An annotated tag object: name, message, tagger, and the object it tags. `get_git_ref` gives a tag's SHA.",
            schema: Schema.object(repository, ["sha": Schema.string("The tag object's SHA.")], required: required + ["sha"])
        ) { arguments, context in
            try .json(await git(arguments, context).tag(arguments.string("sha")))
        },
    ]

    // MARK: Writing

    static let writing: [GitHubTool] = [
        GitHubTool(
            "create_git_tree",
            title: "Create Git tree",
            kind: .write,
            description: """
                Creates a tree, the first step of a commit that changes several files. Pass the current commit's \
                tree as `base` to change only the listed paths. Then call `create_git_commit` and `update_git_ref`.
                """,
            schema: Schema.object(
                repository,
                [
                    "entries": Schema.array(
                        of: Schema.object(
                            [
                                "path": Schema.string("The file's path, such as `docs/setup.md`."),
                                "content": Schema.string("The file's new text."),
                                "sha": Schema.string("An existing blob or tree SHA, instead of `content`."),
                                "delete": Schema.boolean("Removes the path from `base`."),
                                "mode": Schema.oneOf(modes, "Defaults to `file`, or `directory` for a tree SHA."),
                            ],
                            required: ["path"]
                        ),
                        "The paths to add, change, or delete. Each needs one of `content`, `sha`, or `delete`."),
                    "base": Schema.string("The SHA of the tree to start from. Without it, the entries are the whole tree."),
                ],
                required: required + ["entries"]
            )
        ) { arguments, context in
            try .json(await git(arguments, context).createTree(treeEntries(arguments), base: arguments.optionalString("base")))
        },
        GitHubTool(
            "create_git_blob",
            title: "Create Git blob",
            kind: .write,
            description: "Stores file content and returns its SHA, for `create_git_tree`. Use it for binary files; text can go straight in the tree.",
            schema: Schema.object(
                repository,
                [
                    "content": Schema.string("The content: text, or base64 with `base64` set."),
                    "base64": Schema.boolean("Whether `content` is base64. Defaults to false."),
                ],
                required: required + ["content"]
            )
        ) { arguments, context in
            let content = try arguments.text("content")
            let api = try git(arguments, context)
            guard try arguments.bool("base64", default: false) else { return try .json(await api.createBlob(text: content)) }
            guard let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters) else {
                throw ToolFailure("`content` isn't valid base64.")
            }
            return try .json(await api.createBlob(data))
        },
        GitHubTool(
            "create_git_commit",
            title: "Create Git commit",
            kind: .write,
            description: "Creates a commit from a tree. It isn't on a branch until `update_git_ref` or `create_git_ref` points to it.",
            schema: Schema.object(
                repository,
                [
                    "message": Schema.string("The commit message."),
                    "tree": Schema.string("The tree SHA, from `create_git_tree`."),
                    "parents": Schema.array(
                        of: Schema.string("A commit SHA."), "The parent commits, usually the branch's current commit."),
                ],
                required: required + ["message", "tree", "parents"]
            )
        ) { arguments, context in
            let commit = NewGitCommit(
                message: try arguments.text("message"), tree: try arguments.string("tree"), parents: try arguments.requiredStrings("parents"))
            return try .json(await git(arguments, context).createCommit(commit))
        },
        GitHubTool(
            "create_git_ref",
            title: "Create Git reference",
            kind: .write,
            description: "Creates a branch or tag pointing at a SHA.",
            schema: Schema.object(
                repository,
                [
                    "ref": Schema.string("Such as `heads/feature` or `tags/v1.0`."),
                    "sha": Schema.string("The commit (or tag object) to point at."),
                ],
                required: required + ["ref", "sha"]
            )
        ) { arguments, context in
            try .json(await git(arguments, context).createRef(arguments.string("ref"), at: arguments.string("sha")))
        },
        GitHubTool(
            "update_git_ref",
            title: "Update Git reference",
            kind: .destructive,
            idempotent: true,
            description: """
                Moves a branch or tag to another commit. Without `force`, GitHub only allows a fast-forward, \
                so no commits are lost.
                """,
            schema: Schema.object(
                repository,
                [
                    "ref": Schema.string("Such as `heads/main`."),
                    "sha": Schema.string("The commit to point at."),
                    "force": Schema.boolean("Allow a move that drops commits from the branch. Defaults to false."),
                ],
                required: required + ["ref", "sha"]
            )
        ) { arguments, context in
            try .json(
                await git(arguments, context).updateRef(
                    arguments.string("ref"), to: arguments.string("sha"), force: arguments.bool("force", default: false)))
        },
        GitHubTool(
            "delete_git_ref",
            title: "Delete Git reference",
            kind: .destructive,
            idempotent: true,
            description: "Deletes a branch or tag.",
            schema: Schema.object(repository, ["ref": Schema.string("Such as `heads/old-feature`.")], required: required + ["ref"])
        ) { arguments, context in
            let ref = try arguments.string("ref")
            try await git(arguments, context).deleteRef(ref)
            return .message("Deleted \(ref).")
        },
        GitHubTool(
            "create_git_tag",
            title: "Create Git tag",
            kind: .write,
            description: """
                Creates an annotated tag object. To make it show up as a tag, also call `create_git_ref` with \
                `tags/<name>` and the new tag's SHA.
                """,
            schema: Schema.object(
                repository,
                [
                    "tag": Schema.string("The tag's name, such as `v1.0`."),
                    "message": Schema.string("The tag message."),
                    "sha": Schema.string("The commit to tag."),
                ],
                required: required + ["tag", "message", "sha"]
            )
        ) { arguments, context in
            let tag = NewGitTag(try arguments.string("tag"), message: try arguments.text("message"), object: try arguments.string("sha"))
            return try .json(await git(arguments, context).createTag(tag))
        },
    ]

    /// The `entries` argument of `create_git_tree`.
    static func treeEntries(_ arguments: ToolArguments) throws(ToolFailure) -> [NewGitTreeEntry] {
        guard case .array(let values)? = arguments["entries"], !values.isEmpty else {
            throw ToolFailure("`entries` must be a non-empty array of objects.")
        }
        var entries: [NewGitTreeEntry] = []
        for value in values {
            guard case .object(let object) = value else { throw ToolFailure("Each item in `entries` must be an object.") }
            let entry = ToolArguments(object)
            let path = try entry.string("path")
            let content = try entry.optionalText("content")
            let sha = try entry.optionalString("sha")
            let delete = try entry.bool("delete", default: false)
            let mode = try entry.choice("mode", from: modes)
            switch (content, sha, delete) {
            case (let content?, nil, false):
                entries.append(.file(path, content: content, mode: mode ?? .file))
            case (nil, let sha?, false):
                let mode = mode ?? .file
                let type: GitObjectType = mode == .directory ? .tree : mode == .submodule ? .commit : .blob
                entries.append(NewGitTreeEntry(path: path, mode: mode, type: type, source: .sha(sha)))
            case (nil, nil, true):
                entries.append(.delete(path))
            default:
                throw ToolFailure("Entry `\(path)` needs exactly one of `content`, `sha`, or `delete`.")
            }
        }
        return entries
    }
}

/// A blob for the model: text when it decodes as UTF-8.
struct BlobView: Encodable {
    let sha: String
    let size: Int?
    let text: String?
    /// Why `text` is missing, for binary content.
    let note: String?

    init(_ blob: GitBlob) {
        sha = blob.sha
        size = blob.size
        let data = blob.data
        text = data.flatMap { String(data: $0, encoding: .utf8) }
        note = text == nil ? "The blob is binary (\(blob.size.map { "\($0) bytes" } ?? "unknown size")), so its content isn't shown." : nil
    }
}
