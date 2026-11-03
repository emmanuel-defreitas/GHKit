import Foundation
import GHKit
import MCP

/// Calls any REST endpoint or GraphQL query, for what the other toolsets don't cover.
///
/// The tools exist in both access modes. Read-only toolboxes describe and enforce a narrower version.
enum RawRequestTools {
    static func tools(for access: GitHubToolAccess) -> [GitHubTool] {
        [rest(access), graphQL(access)]
    }

    // MARK: REST

    static func rest(_ access: GitHubToolAccess) -> GitHubTool {
        let methods = access == .readOnly ? ["GET"] : ["GET", "POST", "PUT", "PATCH", "DELETE"]
        let summary =
            access == .readOnly
            ? "Sends a GET request to any GitHub REST API endpoint and returns the JSON response."
            : "Sends a request to any GitHub REST API endpoint and returns the JSON response. It can change or delete data."
        return GitHubTool(
            "github_rest",
            title: "GitHub REST request",
            kind: access == .readOnly ? .read : .destructive,
            description: """
                \(summary) Prefer a dedicated tool when one exists. \
                See https://docs.github.com/rest for paths and parameters.
                """,
            schema: Schema.object(
                [
                    "method": Schema.oneOf(methods, "The HTTP method. Defaults to GET."),
                    "path": Schema.string("The path after the API base URL, such as `/repos/octocat/hello-world/labels`."),
                    "query": Schema.anyObject("Query parameters by name, such as {\"state\": \"open\", \"per_page\": 30}."),
                    "body": Schema.anyObject("A JSON request body, for POST, PUT, and PATCH."),
                ],
                required: ["path"]
            )
        ) { arguments, context in
            let method = try httpMethod(arguments.optionalString("method") ?? "GET")
            if context.access == .readOnly, method != .get {
                throw ToolFailure("This server is read-only, so `github_rest` only sends GET requests.")
            }
            let path = try validatedPath(arguments.string("path"))
            let query = try queryItems(arguments.object("query") ?? [:])
            let body = try arguments.object("body").map { MCP.Value.object($0) }

            let request = GitHubRequest<JSONValue>(
                method: method,
                target: .path(path),
                query: query,
                body: body.map { .json($0) },
                // `204 No Content` and similar have no body to decode.
                decode: { data in data.isEmpty ? .null : try GitHubJSON.decoder().decode(JSONValue.self, from: data) }
            )
            let response = try await context.client.send(request)
            if response.value == .null {
                return .message("GitHub answered HTTP \(response.metadata.statusCode) with no content.")
            }
            return try .json(response.value)
        }
    }

    static func httpMethod(_ name: String) throws(ToolFailure) -> HTTPMethod {
        guard let method = HTTPMethod(rawValue: name.uppercased()) else {
            throw ToolFailure("`method` must be GET, POST, PUT, PATCH, or DELETE.")
        }
        return method
    }

    /// The path, if it stays on the client's API server.
    ///
    /// Paths only, never URLs, so the client's token can't be sent to another host.
    static func validatedPath(_ path: String) throws(ToolFailure) -> String {
        let pathOnly = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        let segments = pathOnly.split(separator: "/", omittingEmptySubsequences: false)
        guard path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("://"),
            !segments.contains(where: { $0 == ".." || $0 == "." || $0.removingPercentEncoding == ".." })
        else {
            throw ToolFailure("`path` must be an API path that starts with `/`, such as `/user`, not a URL.")
        }
        guard !path.contains("?") else {
            throw ToolFailure("Pass query parameters in `query`, not in `path`.")
        }
        return path
    }

    static func queryItems(_ query: [String: MCP.Value]) throws(ToolFailure) -> [URLQueryItem] {
        try query.keys.sorted().map { name throws(ToolFailure) in
            let text: String =
                switch query[name]! {
                case .string(let value): value
                case .int(let value): String(value)
                case .double(let value): value.formatted(.number.grouping(.never))
                case .bool(let value): String(value)
                case .array(let values):
                    // GitHub takes lists as comma-separated values, such as `labels=bug,ui`.
                    try values.map { value throws(ToolFailure) in
                        guard let text = value.stringValue ?? value.intValue.map(String.init) else {
                            throw ToolFailure("Query parameter `\(name)` must hold strings or numbers.")
                        }
                        return text
                    }.joined(separator: ",")
                default: throw ToolFailure("Query parameter `\(name)` must be a string, number, or boolean.")
                }
            return URLQueryItem(name: name, value: text)
        }
    }

    // MARK: GraphQL

    static func graphQL(_ access: GitHubToolAccess) -> GitHubTool {
        let summary =
            access == .readOnly
            ? "Runs a query against GitHub's GraphQL API and returns its `data`. Mutations aren't allowed."
            : "Runs a query or mutation against GitHub's GraphQL API and returns its `data`. Mutations can change or delete data."
        return GitHubTool(
            "github_graphql",
            title: "GitHub GraphQL request",
            kind: access == .readOnly ? .read : .destructive,
            description: """
                \(summary) Prefer a dedicated tool when one exists. \
                See https://docs.github.com/graphql for the schema.
                """,
            schema: Schema.object(
                [
                    "query": Schema.string("The GraphQL document, such as `query { viewer { login } }`."),
                    "variables": Schema.anyObject("Values for the document's variables, by name."),
                ],
                required: ["query"]
            )
        ) { arguments, context in
            let document = try arguments.string("query")
            if context.access == .readOnly, GraphQLDocument.hasMutation(document) {
                throw ToolFailure("This server is read-only, so `github_graphql` doesn't run mutations or subscriptions.")
            }
            let variables = MCP.Value.object(try arguments.object("variables") ?? [:])
            return try .json(await context.client.graphQL(document, variables: variables, as: JSONValue.self))
        }
    }
}

/// Just enough GraphQL parsing to tell queries from mutations.
enum GraphQLDocument {
    /// Whether any operation in `document` is a mutation or a subscription.
    ///
    /// The operation keyword is the first word of a top-level definition. Later words, such as an
    /// operation or fragment name, are names even when they read `mutation`.
    ///
    /// The scan reads Unicode scalars, as GraphQL's lexer does. Swift's `Character` would merge a
    /// combining mark into the `#` or `"` before it and hide a comment or string from the scan.
    static func hasMutation(_ document: String) -> Bool {
        let scalars = Array(document.unicodeScalars)
        var braces = 0
        var parentheses = 0
        var atDefinitionStart = true
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            switch scalar {
            case "#":
                // Comments end at LF or CR, exactly as GraphQL's lexer ends them. Ending them anywhere
                // else would misread what follows, such as a `"""` that GitHub sees as commented out.
                while index < scalars.count, !isLineTerminator(scalars[index]) { index += 1 }
                continue
            case "\"":
                index = endOfString(in: scalars, from: index)
                continue
            case "{":
                braces += 1
                atDefinitionStart = false
            case "}":
                braces -= 1
                // Closing a top-level selection set ends the definition.
                if braces == 0 { atDefinitionStart = true }
            case "(": parentheses += 1
            case ")": parentheses -= 1
            case _ where isNameStart(scalar):
                var end = index + 1
                while end < scalars.count, isNameStart(scalars[end]) || ("0"..."9").contains(scalars[end]) { end += 1 }
                if braces == 0, parentheses == 0, atDefinitionStart {
                    let word = String(String.UnicodeScalarView(scalars[index..<end]))
                    if word == "mutation" || word == "subscription" { return true }
                    atDefinitionStart = false
                }
                index = end
                continue
            default: break
            }
            index += 1
        }
        return false
    }

    /// GraphQL's line terminators. U+2028 and U+2029 aren't, so strings and comments may contain them.
    private static func isLineTerminator(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\n" || scalar == "\r"
    }

    /// GraphQL names are ASCII: `[_A-Za-z][_0-9A-Za-z]*`.
    private static func isNameStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    /// The index just past the string that starts at `start`, handling escapes and `"""` blocks.
    private static func endOfString(in scalars: [Unicode.Scalar], from start: Int) -> Int {
        func hasPrefix(_ prefix: String, at index: Int) -> Bool {
            let prefix = Array(prefix.unicodeScalars)
            return index + prefix.count <= scalars.count && Array(scalars[index..<index + prefix.count]) == prefix
        }
        if hasPrefix("\"\"\"", at: start) {
            // Block strings end at the first `"""` that isn't escaped as `\"""`.
            var index = start + 3
            while index < scalars.count {
                if hasPrefix("\\\"\"\"", at: index) {
                    index += 4
                } else if hasPrefix("\"\"\"", at: index) {
                    return index + 3
                } else {
                    index += 1
                }
            }
            return scalars.count
        }
        var index = start + 1
        while index < scalars.count {
            switch scalars[index] {
            // A plain string can't span lines, so a line terminator ends it, even after a backslash.
            case "\\" where index + 1 < scalars.count && isLineTerminator(scalars[index + 1]): return index + 1
            case "\\": index = min(index + 2, scalars.count)
            case "\"": return index + 1
            case _ where isLineTerminator(scalars[index]): return index
            default: index += 1
            }
        }
        return scalars.count
    }
}
