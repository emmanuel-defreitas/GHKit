import Foundation
import GHKit
import MCP

/// Repositories, their files, branches, commits, and releases.
///
/// Deleting or transferring a whole repository, and branch protection, are left to `github_rest`:
/// they're rare for an assistant and hard to undo.
enum RepositoryTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        repositories + contents + branchesAndCommits + releases
    }

    static let repository = Schema.repository
    static let required = ["owner", "repo"]

    static let repositorySorts: KeyValuePairs<String, RepositorySort> = [
        "full_name": .fullName, "created": .created, "updated": .updated, "pushed": .pushed,
    ]
    static let forkSorts: KeyValuePairs<String, ForkSort> = [
        "newest": .newest, "oldest": .oldest, "stargazers": .stargazers, "watchers": .watchers,
    ]

    // MARK: Repositories

    static let repositories: [GitHubTool] = [
        GitHubTool(
            "get_repository",
            title: "Get repository",
            description: "One repository: description, visibility, default branch, topics, license, counts, and settings.",
            schema: Schema.object(repository, required: required)
        ) { arguments, context in
            try .json(await context.client.repositories.repository(arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "list_repositories",
            title: "List repositories",
            description: """
                Repositories of a user (`user`), of an organization (`org`), or, with neither, every repository \
                the signed-in user can access.
                """,
            schema: Schema.object(
                [
                    "user": Schema.string("A user's login, for their public repositories."),
                    "org": Schema.string("An organization's login, for its repositories you can see."),
                    "sort": Schema.oneOf(repositorySorts, "The order. Defaults to `full_name`, or `created` for an organization."),
                ],
                Schema.paging
            )
        ) { arguments, context in
            let repositories = context.client.repositories
            let sort = try arguments.choice("sort", from: repositorySorts)
            let perPage = try arguments.perPage
            switch (try arguments.optionalString("user"), try arguments.optionalString("org")) {
            case (_?, _?):
                throw ToolFailure("Pass `user` or `org`, not both.")
            case (let user?, nil):
                return try await .page(repositories.list(of: user, sort: sort ?? .fullName, perPage: perPage), arguments, context)
            case (nil, let org?):
                return try await .page(repositories.list(in: org, sort: sort ?? .created, perPage: perPage), arguments, context)
            case (nil, nil):
                return try await .page(repositories.list(sort: sort ?? .fullName, perPage: perPage), arguments, context)
            }
        },
        GitHubTool(
            "get_repository_languages",
            title: "Get repository languages",
            description: "Bytes of code per language in a repository.",
            schema: Schema.object(repository, required: required)
        ) { arguments, context in
            try .json(await context.client.repositories.languages(arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "list_contributors",
            title: "List contributors",
            description: "A repository's contributors, most commits first.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let list = try context.client.repositories.contributors(
                arguments.string("owner"), arguments.string("repo"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_forks",
            title: "List forks",
            description: "Forks of a repository.",
            schema: Schema.object(
                repository, ["sort": Schema.oneOf(forkSorts, "The order. Defaults to `newest`.")], Schema.paging,
                required: required)
        ) { arguments, context in
            let list = try context.client.repositories.forks(
                arguments.string("owner"), arguments.string("repo"), sort: arguments.choice("sort", from: forkSorts) ?? .newest,
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "create_repository",
            title: "Create repository",
            kind: .write,
            description: "Creates a repository for the signed-in user, or in an organization when `org` is set.",
            schema: Schema.object(
                [
                    "name": Schema.string("The new repository's name."),
                    "description": Schema.string("A short description."),
                    "private": Schema.boolean("Whether only invited people can see it. Defaults to false."),
                    "org": Schema.string("An organization to create it in, instead of the signed-in user's account."),
                    "autoInit": Schema.boolean("Whether to start with a README commit. Defaults to false."),
                ],
                required: ["name"]
            )
        ) { arguments, context in
            let repository = NewRepository(
                name: try arguments.string("name"),
                description: try arguments.optionalString("description"),
                visibility: try arguments.optionalBool("private").map { $0 ? .private : .public },
                autoInitialize: try arguments.optionalBool("autoInit")
            )
            if let org = try arguments.optionalString("org") {
                return try .json(await context.client.repositories.create(repository, in: org))
            }
            return try .json(await context.client.repositories.create(repository))
        },
        GitHubTool(
            "update_repository",
            title: "Update repository",
            kind: .write,
            idempotent: true,
            description: "Changes a repository's description, homepage, visibility, default branch, features, or archived state.",
            schema: Schema.object(
                repository,
                [
                    "description": Schema.string("A short description."),
                    "homepage": Schema.string("A URL for the project."),
                    "private": Schema.boolean("Whether only invited people can see it."),
                    "defaultBranch": Schema.string("The branch pull requests target by default."),
                    "hasIssues": Schema.boolean("Whether issues are on."),
                    "hasWiki": Schema.boolean("Whether the wiki is on."),
                    "archived": Schema.boolean("Whether the repository is read-only. Unarchiving is possible later."),
                ],
                required: required
            )
        ) { arguments, context in
            let changes = RepositoryUpdate(
                description: try arguments.optionalString("description"),
                homepage: try arguments.optionalString("homepage"),
                visibility: try arguments.optionalBool("private").map { $0 ? .private : .public },
                defaultBranch: try arguments.optionalString("defaultBranch"),
                hasIssues: try arguments.optionalBool("hasIssues"),
                hasWiki: try arguments.optionalBool("hasWiki"),
                archived: try arguments.optionalBool("archived")
            )
            return try .json(
                await context.client.repositories.update(arguments.string("owner"), arguments.string("repo"), changes))
        },
        GitHubTool(
            "fork_repository",
            title: "Fork repository",
            kind: .write,
            description: "Forks a repository to the signed-in user or an organization. GitHub copies it in the background.",
            schema: Schema.object(
                repository,
                [
                    "org": Schema.string("An organization to fork into, instead of the signed-in user's account."),
                    "name": Schema.string("A name for the fork. Defaults to the original name."),
                    "defaultBranchOnly": Schema.boolean("Whether to copy only the default branch."),
                ],
                required: required
            )
        ) { arguments, context in
            try .json(
                await context.client.repositories.fork(
                    arguments.string("owner"), arguments.string("repo"), into: arguments.optionalString("org"),
                    as: arguments.optionalString("name"), defaultBranchOnly: arguments.optionalBool("defaultBranchOnly")))
        },
        GitHubTool(
            "replace_topics",
            title: "Replace topics",
            kind: .write,
            idempotent: true,
            description: "Replaces a repository's topics. Topics are lowercase, with hyphens. Pass an empty list to clear them.",
            schema: Schema.object(
                repository, ["topics": Schema.array(of: ["type": "string"], "Every topic the repository should have.")],
                required: required + ["topics"])
        ) { arguments, context in
            try .json(
                await context.client.repositories.replaceTopics(
                    arguments.strings("topics"), on: arguments.string("owner"), arguments.string("repo")))
        },
    ]

    // MARK: Contents

    static let contents: [GitHubTool] = [
        GitHubTool(
            "get_file_contents",
            title: "Get file or directory",
            description: """
                A file's text, or a directory's entries. Pass the file's `sha` back to \
                `create_or_update_file` or `delete_file` to change it.
                """,
            schema: Schema.object(
                repository,
                [
                    "path": Schema.string("A path such as `Sources/App.swift`. Empty or omitted for the root directory."),
                    "ref": Schema.string("A branch, tag, or commit SHA. Defaults to the default branch."),
                ],
                required: required
            )
        ) { arguments, context in
            let contents = try await context.client.repositories.contents(
                arguments.string("owner"), arguments.string("repo"), at: arguments.optionalString("path") ?? "",
                ref: arguments.optionalString("ref"))
            switch contents {
            case .item(let item): return try .json(FileView(item))
            case .directory(let entries): return try .json(DirectoryView(entries))
            }
        },
        GitHubTool(
            "get_readme",
            title: "Get README",
            description: "A repository's README as text.",
            schema: Schema.object(
                repository, ["ref": Schema.string("A branch, tag, or commit SHA. Defaults to the default branch.")],
                required: required)
        ) { arguments, context in
            try .json(
                FileView(
                    await context.client.repositories.readme(
                        arguments.string("owner"), arguments.string("repo"), ref: arguments.optionalString("ref"))))
        },
        GitHubTool(
            "create_or_update_file",
            title: "Create or update file",
            kind: .write,
            description: """
                Commits a text file. To replace an existing file, pass its current `sha` from `get_file_contents`.
                """,
            schema: Schema.object(
                repository,
                [
                    "path": Schema.string("The file's path, such as `docs/setup.md`."),
                    "content": Schema.string("The whole new file, as text."),
                    "message": Schema.string("The commit message."),
                    "branch": Schema.string("The branch to commit to. Defaults to the default branch."),
                    "sha": Schema.string("The current blob SHA, when replacing a file."),
                ],
                required: required + ["path", "content", "message"]
            )
        ) { arguments, context in
            let change = FileChange(
                message: try arguments.string("message"),
                text: try arguments.optionalString("content") ?? "",
                replacing: try arguments.optionalString("sha"),
                branch: try arguments.optionalString("branch")
            )
            let commit = try await context.client.repositories.writeFile(
                change, to: arguments.string("path"), in: arguments.string("owner"), arguments.string("repo"))
            return try .json(FileCommitView(commit))
        },
        GitHubTool(
            "delete_file",
            title: "Delete file",
            kind: .destructive,
            description: "Deletes a file in a new commit. Pass its current `sha` from `get_file_contents`.",
            schema: Schema.object(
                repository,
                [
                    "path": Schema.string("The file's path."),
                    "sha": Schema.string("The file's current blob SHA."),
                    "message": Schema.string("The commit message."),
                    "branch": Schema.string("The branch to commit to. Defaults to the default branch."),
                ],
                required: required + ["path", "sha", "message"]
            )
        ) { arguments, context in
            let commit = try await context.client.repositories.deleteFile(
                arguments.string("path"), sha: arguments.string("sha"), message: arguments.string("message"),
                in: arguments.string("owner"), arguments.string("repo"), branch: arguments.optionalString("branch"))
            return try .json(FileCommitView(commit))
        },
    ]

    // MARK: Branches and commits

    static let branchesAndCommits: [GitHubTool] = [
        GitHubTool(
            "list_branches",
            title: "List branches",
            description: "A repository's branches with their head commits.",
            schema: Schema.object(
                repository, ["protected": Schema.boolean("Only protected branches when true, only unprotected ones when false.")],
                Schema.paging, required: required)
        ) { arguments, context in
            let list = try context.client.repositories.branches(
                arguments.string("owner"), arguments.string("repo"), protected: arguments.optionalBool("protected"),
                perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_branch",
            title: "Get branch",
            description: "One branch, with its head commit and whether it's protected.",
            schema: Schema.object(repository, ["branch": Schema.string("The branch name.")], required: required + ["branch"])
        ) { arguments, context in
            try .json(
                await context.client.repositories.branch(
                    arguments.string("branch"), in: arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "merge_branch",
            title: "Merge branch",
            kind: .write,
            description: "Merges a branch or commit into another branch, without a pull request.",
            schema: Schema.object(
                repository,
                [
                    "base": Schema.string("The branch to merge into."),
                    "head": Schema.string("The branch or commit SHA to merge."),
                    "message": Schema.string("The merge commit's message. Defaults to GitHub's."),
                ],
                required: required + ["base", "head"]
            )
        ) { arguments, context in
            let head = try arguments.string("head")
            let base = try arguments.string("base")
            guard
                let commit = try await context.client.repositories.merge(
                    head, into: base, in: arguments.string("owner"), arguments.string("repo"),
                    message: arguments.optionalString("message"))
            else {
                return .message("Nothing to merge: `\(base)` already contains `\(head)`.")
            }
            return try .json(commit)
        },
        GitHubTool(
            "list_tags",
            title: "List tags",
            description: "A repository's tags, newest first.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let list = try context.client.repositories.tags(arguments.string("owner"), arguments.string("repo"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "list_commits",
            title: "List commits",
            description: "A repository's commits, newest first, optionally limited to a branch, path, author, or time range.",
            schema: Schema.object(
                repository,
                [
                    "ref": Schema.string("A branch, tag, or SHA to start from. Defaults to the default branch."),
                    "path": Schema.string("Only commits that touch this file or directory."),
                    "author": Schema.string("Only commits by this login or email."),
                    "since": Schema.date("Only commits after this time."),
                    "until": Schema.date("Only commits before this time."),
                ],
                Schema.paging,
                required: required
            )
        ) { arguments, context in
            let list = try context.client.repositories.commits(
                arguments.string("owner"), arguments.string("repo"), ref: arguments.optionalString("ref"),
                path: arguments.optionalString("path"), author: arguments.optionalString("author"),
                since: arguments.optionalDate("since"), until: arguments.optionalDate("until"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_commit",
            title: "Get commit",
            description: "One commit with its message, stats, and changed files with their patches (up to 300 files).",
            schema: Schema.object(repository, ["ref": Schema.string("A commit SHA, branch, or tag.")], required: required + ["ref"])
        ) { arguments, context in
            try .json(
                await context.client.repositories.commit(arguments.string("ref"), in: arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "compare_commits",
            title: "Compare commits",
            description: """
                How `head` relates to `base`: ahead and behind counts, and the commits (up to 250) and files between them.
                """,
            schema: Schema.object(
                repository,
                [
                    "base": Schema.string("The branch, tag, or SHA to compare from."),
                    "head": Schema.string("The branch, tag, or SHA to compare to. Use `owner:branch` for a fork."),
                ],
                required: required + ["base", "head"]
            )
        ) { arguments, context in
            try .json(
                await context.client.repositories.compare(
                    arguments.string("base"), arguments.string("head"), in: arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "get_commit_status",
            title: "Get commit status",
            description: "The combined status of a commit: the overall state and the latest status for each context.",
            schema: Schema.object(repository, ["ref": Schema.string("A commit SHA, branch, or tag.")], required: required + ["ref"])
        ) { arguments, context in
            try .json(
                await context.client.repositories.combinedStatus(
                    for: arguments.string("ref"), in: arguments.string("owner"), arguments.string("repo")))
        },
    ]

    // MARK: Releases

    static let releaseFields: [String: MCP.Value] = [
        "name": Schema.string("The release title."),
        "body": Schema.string("Release notes, in Markdown."),
        "target": Schema.string("The branch or SHA to tag, if the tag doesn't exist yet. Defaults to the default branch."),
        "draft": Schema.boolean("Whether to save it unpublished."),
        "prerelease": Schema.boolean("Whether to mark it as a prerelease."),
    ]

    static let releases: [GitHubTool] = [
        GitHubTool(
            "list_releases",
            title: "List releases",
            description: "A repository's releases, newest first. Drafts appear only with push access.",
            schema: Schema.object(repository, Schema.paging, required: required)
        ) { arguments, context in
            let list = try context.client.repositories.releases(arguments.string("owner"), arguments.string("repo"), perPage: arguments.perPage)
            return try await .page(list, arguments, context)
        },
        GitHubTool(
            "get_release",
            title: "Get release",
            description: "One release by `tag` or `id`, or the latest published release when you pass neither.",
            schema: Schema.object(
                repository, ["tag": Schema.string("The release's tag, such as `v1.2.0`."), "id": Schema.integer("The release ID.")],
                required: required)
        ) { arguments, context in
            let (owner, repo) = (try arguments.string("owner"), try arguments.string("repo"))
            let repositories = context.client.repositories
            if let tag = try arguments.optionalString("tag") {
                return try .json(await repositories.release(tag: tag, in: owner, repo))
            }
            if let id = try arguments.optionalInt("id") {
                return try .json(await repositories.release(id: id, in: owner, repo))
            }
            return try .json(await repositories.latestRelease(owner, repo))
        },
        GitHubTool(
            "generate_release_notes",
            title: "Generate release notes",
            description: "Drafts release notes from the pull requests merged since the previous release. Saves nothing.",
            schema: Schema.object(
                repository,
                [
                    "tag": Schema.string("The tag the release will have."),
                    "target": Schema.string("The branch or SHA the tag will point at, if it doesn't exist yet."),
                    "previousTag": Schema.string("The tag to start from. Defaults to the previous release."),
                ],
                required: required + ["tag"]
            )
        ) { arguments, context in
            try .json(
                await context.client.repositories.generateReleaseNotes(
                    for: arguments.string("tag"), in: arguments.string("owner"), arguments.string("repo"),
                    target: arguments.optionalString("target"), previousTag: arguments.optionalString("previousTag")))
        },
        GitHubTool(
            "create_release",
            title: "Create release",
            kind: .write,
            description: "Creates a release, and its tag if needed.",
            schema: Schema.object(
                repository, releaseFields,
                [
                    "tag": Schema.string("The tag, such as `v1.2.0`."),
                    "generateNotes": Schema.boolean("Whether GitHub writes the notes from merged pull requests."),
                ],
                required: required + ["tag"]
            )
        ) { arguments, context in
            let release = NewRelease(
                tagName: try arguments.string("tag"),
                targetCommitish: try arguments.optionalString("target"),
                name: try arguments.optionalString("name"),
                body: try arguments.optionalString("body"),
                isDraft: try arguments.optionalBool("draft"),
                isPrerelease: try arguments.optionalBool("prerelease"),
                generateReleaseNotes: try arguments.optionalBool("generateNotes")
            )
            return try .json(
                await context.client.repositories.createRelease(release, in: arguments.string("owner"), arguments.string("repo")))
        },
        GitHubTool(
            "update_release",
            title: "Update release",
            kind: .write,
            idempotent: true,
            description: "Changes a release. Set `draft` to false to publish a draft.",
            schema: Schema.object(
                repository, releaseFields,
                ["id": Schema.integer("The release ID."), "tag": Schema.string("A new tag for the release.")],
                required: required + ["id"]
            )
        ) { arguments, context in
            let changes = ReleaseUpdate(
                tagName: try arguments.optionalString("tag"),
                targetCommitish: try arguments.optionalString("target"),
                name: try arguments.optionalString("name"),
                body: try arguments.optionalString("body"),
                isDraft: try arguments.optionalBool("draft"),
                isPrerelease: try arguments.optionalBool("prerelease")
            )
            return try .json(
                await context.client.repositories.updateRelease(
                    id: arguments.int("id"), in: arguments.string("owner"), arguments.string("repo"), changes))
        },
        GitHubTool(
            "delete_release",
            title: "Delete release",
            kind: .destructive,
            idempotent: true,
            description: "Deletes a release. Its tag stays.",
            schema: Schema.object(repository, ["id": Schema.integer("The release ID.")], required: required + ["id"])
        ) { arguments, context in
            let id = try arguments.int("id")
            try await context.client.repositories.deleteRelease(id: id, in: arguments.string("owner"), arguments.string("repo"))
            return .message("Deleted release \(id).")
        },
    ]
}

// MARK: - Views

/// A file as text, without GitHub's base64 encoding.
struct FileView: Encodable {
    let type: String
    let path: String
    let sha: String
    let size: Int
    let text: String?
    /// Why `text` is missing, for binary or large files.
    let note: String?
    let htmlURL: URL?
    let target: String?

    init(_ item: RepositoryContent) {
        type = item.type.rawValue
        path = item.path
        sha = item.sha
        size = item.size
        target = item.target
        htmlURL = item.htmlURL
        text = item.text
        note =
            switch (item.type, item.text, item.data) {
            case (.file, nil, nil): "The file is too large to return inline (\(item.size) bytes)."
            case (.file, nil, _?): "The file is binary (\(item.size) bytes), so its contents aren't shown."
            default: nil
            }
    }

    enum CodingKeys: String, CodingKey {
        case type, path, sha, size, text, note, target
        case htmlURL = "html_url"
    }
}

/// A directory's entries, without links.
struct DirectoryView: Encodable {
    struct Entry: Encodable {
        let type: String
        let name: String
        let path: String
        let size: Int
        let sha: String
    }

    let entries: [Entry]

    init(_ entries: [RepositoryContent]) {
        self.entries = entries.map { Entry(type: $0.type.rawValue, name: $0.name, path: $0.path, size: $0.size, sha: $0.sha) }
    }
}

/// The commit a file change made, and the file's new blob SHA.
struct FileCommitView: Encodable {
    let commitSHA: String
    let commitURL: URL?
    let path: String?
    let sha: String?

    init(_ commit: FileCommit) {
        commitSHA = commit.commit.sha
        commitURL = commit.commit.htmlURL
        path = commit.content?.path
        sha = commit.content?.sha
    }

    enum CodingKeys: String, CodingKey {
        case path, sha
        case commitSHA = "commit_sha"
        case commitURL = "commit_url"
    }
}
