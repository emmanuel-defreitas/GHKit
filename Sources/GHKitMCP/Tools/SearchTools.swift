import GHKit
import MCP

/// GitHub search: code, issues and pull requests, repositories, users, and commits.
enum SearchTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [
            search(
                "search_code", title: "Search code",
                description: """
                    Files whose contents or paths match, in each repository's default branch. Use qualifiers such as \
                    `repo:owner/name`, `language:swift`, `path:Sources`, or `extension:md`.
                    """,
                example: "`addClass in:file language:js repo:jquery/jquery`",
                sorts: noSorts
            ) { query, _, arguments, client in
                client.search.code(query, perPage: try arguments.perPage)
            },
            search(
                "search_issues", title: "Search issues and pull requests",
                description: """
                    Issues and pull requests that match. The query must include `is:issue` or `is:pr`. Use qualifiers \
                    such as `repo:owner/name`, `state:open`, `author:login`, `label:bug`, or `involves:@me`.
                    """,
                example: "`is:pr is:open review-requested:@me`",
                sorts: issueSorts
            ) { query, sort, arguments, client in
                client.search.issues(query, sort: sort, perPage: try arguments.perPage)
            },
            search(
                "search_repositories", title: "Search repositories",
                description: """
                    Repositories that match. Use qualifiers such as `user:login`, `org:name`, `language:swift`, \
                    `topic:mcp`, or `stars:>100`.
                    """,
                example: "`swift mcp in:name,description stars:>10`",
                sorts: repositorySorts
            ) { query, sort, arguments, client in
                client.search.repositories(query, sort: sort, perPage: try arguments.perPage)
            },
            search(
                "search_users", title: "Search users",
                description: "Users and organizations that match. Use qualifiers such as `type:org`, `location:Paris`, or `followers:>100`.",
                example: "`tom location:London type:user`",
                sorts: userSorts
            ) { query, sort, arguments, client in
                client.search.users(query, sort: sort, perPage: try arguments.perPage)
            },
            search(
                "search_commits", title: "Search commits",
                description: """
                    Commits in default branches whose messages or metadata match. Use qualifiers such as \
                    `repo:owner/name`, `author:login`, or `committer-date:>2026-01-01`.
                    """,
                example: "`fix crash repo:octocat/Hello-World`",
                sorts: commitSorts
            ) { query, sort, arguments, client in
                client.search.commits(query, sort: sort, perPage: try arguments.perPage)
            },
        ]
    }

    /// Code search has no sort orders of its own.
    static let noSorts: KeyValuePairs<String, Never> = [:]
    static let issueSorts: KeyValuePairs<String, IssueSearchSort> = [
        "comments": .comments, "reactions": .reactions, "interactions": .interactions, "created": .created, "updated": .updated,
    ]
    static let repositorySorts: KeyValuePairs<String, RepositorySearchSort> = [
        "stars": .stars, "forks": .forks, "updated": .updated, "help_wanted_issues": .helpWantedIssues,
    ]
    static let userSorts: KeyValuePairs<String, UserSearchSort> = [
        "followers": .followers, "repositories": .repositories, "joined": .joined,
    ]
    static let commitSorts: KeyValuePairs<String, CommitSearchSort> = [
        "author_date": .authorDate, "committer_date": .committerDate,
    ]

    /// A search tool that takes `query`, an optional `sort`, and paging.
    static func search<Item: Encodable & Sendable, Sort: Sendable>(
        _ name: String,
        title: String,
        description: String,
        example: String,
        sorts: KeyValuePairs<String, Sort>,
        list: @escaping @Sendable (String, Sort?, ToolArguments, GitHubClient) throws -> Paginated<Item>
    ) -> GitHubTool {
        var properties: [String: MCP.Value] = ["query": Schema.string("The search query, such as \(example).")]
        if !sorts.isEmpty { properties["sort"] = Schema.oneOf(sorts, "The order. Defaults to best match.") }
        // `KeyValuePairs` isn't `Sendable`, so capture the names and values separately.
        let names = sorts.map(\.key)
        let values = sorts.map(\.value)
        return GitHubTool(
            name, title: title,
            description: description + " Results are ranked by relevance, and GitHub returns at most 1000 per search.",
            schema: Schema.object(properties, Schema.paging, required: ["query"])
        ) { arguments, context in
            var sort: Sort?
            if let name = try arguments.optionalString("sort") {
                guard let index = names.firstIndex(of: name) else {
                    throw ToolFailure("`sort` must be one of: \(names.joined(separator: ", ")).")
                }
                sort = values[index]
            }
            return try await .page(list(arguments.string("query"), sort, arguments, context.client), arguments, context)
        }
    }
}
