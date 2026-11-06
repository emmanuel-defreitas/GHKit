import Foundation
import GHKit
import MCP

/// Licenses, `.gitignore` templates, codes of conduct, Markdown rendering, and GitHub's service information.
enum MetaTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [
            GitHubTool(
                "render_markdown",
                title: "Render Markdown",
                description: """
                    Markdown as the HTML GitHub would show. Use `gfm` with `owner` and `repo` to link `#42` \
                    references and @mentions like a comment does.
                    """,
                schema: Schema.object(
                    [
                        "text": Schema.string("The Markdown."),
                        "mode": Schema.oneOf(modes, "`markdown` like a README, or `gfm` like a comment. Defaults to `markdown`."),
                        "owner": Schema.string("With `repo`, the repository that `#42` references point to."),
                        "repo": Schema.string("With `owner`, the repository that `#42` references point to."),
                    ],
                    required: ["text"]
                )
            ) { arguments, context in
                let repository = try repositoryContext(arguments)
                let html = try await context.client.meta.renderMarkdown(
                    arguments.text("text"), mode: arguments.choice("mode", from: modes) ?? .markdown, context: repository)
                return .message(html)
            },
            GitHubTool(
                "list_licenses",
                title: "List licenses",
                description: "Commonly used open source licenses, with their keys for `get_license`.",
                schema: Schema.object(
                    ["featured": Schema.boolean("Only the licenses GitHub suggests for new repositories.")], Schema.paging)
            ) { arguments, context in
                try await .page(
                    context.client.meta.licenses(featured: arguments.optionalBool("featured"), perPage: arguments.perPage), arguments, context)
            },
            GitHubTool(
                "get_license",
                title: "Get license",
                description: "One license's text, with what it permits, requires, and rules out.",
                schema: Schema.object(["key": Schema.string("Such as `mit` or `apache-2.0`.")], required: ["key"])
            ) { arguments, context in
                try .json(await context.client.meta.license(arguments.string("key")))
            },
            GitHubTool(
                "list_gitignore_templates",
                title: "List .gitignore templates",
                description: "The names of GitHub's `.gitignore` templates, such as `Swift` or `Node`."
            ) { _, context in
                try .list(await context.client.meta.gitignoreTemplates())
            },
            GitHubTool(
                "get_gitignore_template",
                title: "Get .gitignore template",
                description: "One `.gitignore` template's content.",
                schema: Schema.object(["name": Schema.string("Such as `Swift`. Names are case-sensitive.")], required: ["name"])
            ) { arguments, context in
                try .json(await context.client.meta.gitignoreTemplate(arguments.string("name")))
            },
            GitHubTool(
                "list_codes_of_conduct",
                title: "List codes of conduct",
                description: "The codes of conduct GitHub offers, with their keys for `get_code_of_conduct`."
            ) { _, context in
                try .list(await context.client.meta.codesOfConduct())
            },
            GitHubTool(
                "get_code_of_conduct",
                title: "Get code of conduct",
                description: "One code of conduct's text.",
                schema: Schema.object(["key": Schema.string("Such as `contributor_covenant`.")], required: ["key"])
            ) { arguments, context in
                try .json(await context.client.meta.codeOfConduct(arguments.string("key")))
            },
            GitHubTool(
                "get_github_meta",
                title: "Get GitHub service information",
                description: "GitHub's IP ranges by service, SSH host keys and fingerprints, and domains, for firewalls and `known_hosts`."
            ) { _, context in
                try .json(await context.client.meta.overview())
            },
            GitHubTool(
                "list_api_versions",
                title: "List API versions",
                description: "The REST API versions the server supports, for the `X-GitHub-Api-Version` header."
            ) { _, context in
                try .list(await context.client.meta.versions())
            },
        ]
    }

    static let modes: KeyValuePairs<String, MarkdownMode> = ["markdown": .markdown, "gfm": .gfm]

    /// The repository from `owner` and `repo`, or `nil` when neither is set.
    private static func repositoryContext(_ arguments: ToolArguments) throws(ToolFailure) -> (owner: String, name: String)? {
        switch (try arguments.optionalString("owner"), try arguments.optionalString("repo")) {
        case (let owner?, let repo?): (owner, repo)
        case (nil, nil): nil
        default: throw ToolFailure("Pass both `owner` and `repo`, or neither.")
        }
    }
}
