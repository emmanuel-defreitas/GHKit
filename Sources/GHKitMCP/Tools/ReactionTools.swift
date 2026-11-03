import GHKit
import MCP

/// Emoji reactions on issues, pull requests, comments, and releases.
enum ReactionTools {
    static let kinds = ["issue", "issue_comment", "commit_comment", "review_comment", "release"]
    static let contents: KeyValuePairs<String, ReactionContent> = [
        "+1": .thumbsUp, "-1": .thumbsDown, "laugh": .laugh, "confused": .confused, "heart": .heart, "hooray": .hooray,
        "rocket": .rocket, "eyes": .eyes,
    ]

    static let subjectFields: [String: MCP.Value] = [
        "subject": Schema.oneOf(kinds, "What the reaction is on. Pull requests count as `issue`."),
        "id": Schema.integer("The issue or pull request number, or the comment or release ID."),
    ]

    static func subject(_ arguments: ToolArguments) throws(ToolFailure) -> ReactionSubject {
        let id = try arguments.int("id")
        switch try arguments.string("subject") {
        case "issue": return .issue(id)
        case "issue_comment": return .issueComment(id: id)
        case "commit_comment": return .commitComment(id: id)
        case "review_comment": return .reviewComment(id: id)
        case "release": return .release(id: id)
        default: throw ToolFailure("`subject` must be one of: \(kinds.joined(separator: ", ")).")
        }
    }

    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [
            GitHubTool(
                "list_reactions",
                title: "List reactions",
                description: "The emoji reactions on an issue, pull request, comment, or release, and who left them.",
                schema: Schema.object(
                    Schema.repository, subjectFields, ["content": Schema.oneOf(contents, "Only this reaction.")], Schema.paging,
                    required: ["owner", "repo", "subject", "id"])
            ) { arguments, context in
                let list = try context.client.reactions.list(
                    on: subject(arguments), in: arguments.string("owner"), arguments.string("repo"),
                    content: arguments.choice("content", from: contents), perPage: arguments.perPage)
                return try await .page(list, arguments, context)
            },
            GitHubTool(
                "add_reaction",
                title: "Add reaction",
                kind: .write,
                idempotent: true,
                description: "Reacts to an issue, pull request, comment, or release as the signed-in user.",
                schema: Schema.object(
                    Schema.repository, subjectFields, ["content": Schema.oneOf(contents, "The reaction.")],
                    required: ["owner", "repo", "subject", "id", "content"])
            ) { arguments, context in
                guard let content = try arguments.choice("content", from: contents) else {
                    throw ToolFailure("Missing required argument `content`.")
                }
                return try .json(
                    await context.client.reactions.add(content, to: subject(arguments), in: arguments.string("owner"), arguments.string("repo")))
            },
        ]
    }
}
