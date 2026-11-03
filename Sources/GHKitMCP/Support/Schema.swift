import MCP

/// Builds the JSON Schemas that describe tool arguments.
enum Schema {
    /// A tool's arguments. Pass several property groups to combine shared ones, such as ``repository``.
    static func object(_ groups: [String: MCP.Value]..., required: [String] = []) -> MCP.Value {
        let properties = groups.reduce(into: [String: MCP.Value]()) { $0.merge($1) { _, new in new } }
        var schema: [String: MCP.Value] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty { schema["required"] = .array(required.map { .string($0) }) }
        return .object(schema)
    }

    static func string(_ description: String) -> MCP.Value {
        ["type": "string", "description": .string(description)]
    }

    static func integer(_ description: String, minimum: Int? = nil, maximum: Int? = nil) -> MCP.Value {
        var schema: [String: MCP.Value] = ["type": "integer", "description": .string(description)]
        if let minimum { schema["minimum"] = .int(minimum) }
        if let maximum { schema["maximum"] = .int(maximum) }
        return .object(schema)
    }

    static func boolean(_ description: String) -> MCP.Value {
        ["type": "boolean", "description": .string(description)]
    }

    static func oneOf(_ values: [String], _ description: String) -> MCP.Value {
        ["type": "string", "enum": .array(values.map { .string($0) }), "description": .string(description)]
    }

    static func array(of items: MCP.Value, _ description: String) -> MCP.Value {
        ["type": "array", "items": items, "description": .string(description)]
    }

    /// Any JSON object, such as a request body.
    static func anyObject(_ description: String) -> MCP.Value {
        ["type": "object", "description": .string(description)]
    }

    // MARK: Shared groups

    /// `owner` and `repo`.
    static let repository: [String: MCP.Value] = [
        "owner": string("The account that owns the repository, such as `octocat`."),
        "repo": string("The repository name, such as `hello-world`."),
    ]

    /// `perPage` and `cursor`, for tools that return one page of a list.
    static let paging: [String: MCP.Value] = [
        "perPage": integer("Items per page. Defaults to 30.", minimum: 1, maximum: 100),
        "cursor": string("The `nextCursor` from the previous page. Omit it for the first page."),
    ]
}
