import GHKit

/// Who's signed in, and how much of the rate limit is left.
enum ContextTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [
            GitHubTool(
                "get_me",
                title: "Get signed-in user",
                description: "The GitHub user this server acts as: login, name, profile, and plan."
            ) { _, context in
                try .json(await context.client.users.authenticated())
            },
            GitHubTool(
                "get_rate_limit",
                title: "Get rate limits",
                description: """
                    The signed-in user's GitHub API rate limits: limit, remaining, used, and reset time \
                    (Unix seconds) for each bucket, such as `core`, `search`, and `graphql`. \
                    This call doesn't count against them.
                    """
            ) { _, context in
                try .json(await context.client.rateLimit())
            },
        ]
    }
}
