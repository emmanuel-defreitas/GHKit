import GHKit
import MCP

/// One MCP tool backed by GHKit.
struct GitHubTool: Sendable {
    /// What a tool does to GitHub. It decides the MCP hints and whether read-only toolboxes list it.
    enum Kind: Sendable {
        case read
        case write
        /// Deletes or overwrites something.
        case destructive
    }

    /// What a tool's handler gets besides its arguments.
    struct Context: Sendable {
        let client: GitHubClient
        let access: GitHubToolAccess
    }

    typealias Handler = @Sendable (ToolArguments, Context) async throws -> ToolOutput

    let name: String
    let title: String
    let description: String
    let kind: Kind
    /// Calling it twice with the same arguments has no further effect. Only meaningful for writes.
    let idempotent: Bool
    let schema: MCP.Value
    let run: Handler

    init(
        _ name: String,
        title: String,
        kind: Kind = .read,
        idempotent: Bool = false,
        description: String,
        schema: MCP.Value = Schema.object(),
        run: @escaping Handler
    ) {
        self.name = name
        self.title = title
        self.kind = kind
        self.idempotent = idempotent
        self.description = description
        self.schema = schema
        self.run = run
    }

    var definition: Tool {
        Tool(
            name: name,
            title: title,
            description: description,
            inputSchema: schema,
            annotations: Tool.Annotations(
                readOnlyHint: kind == .read,
                destructiveHint: kind == .read ? nil : kind == .destructive,
                idempotentHint: kind == .read ? nil : idempotent,
                openWorldHint: true
            )
        )
    }
}

/// A problem with a tool call that the model can fix, such as a missing argument.
struct ToolFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
