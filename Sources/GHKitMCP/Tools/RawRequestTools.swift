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
    /// Operation keywords only appear outside braces and parentheses, so names there are checked
    /// after skipping comments and strings.
    static func hasMutation(_ document: String) -> Bool {
        var braces = 0
        var parentheses = 0
        var index = document.startIndex
        while index < document.endIndex {
            let character = document[index]
            switch character {
            case "#":
                // Comments end at LF, CR, or CRLF. Swift reads CRLF as one `Character`, so match any newline.
                index = document[index...].firstIndex(where: \.isNewline) ?? document.endIndex
                continue
            case "\"":
                index = endOfString(in: document, from: index)
                continue
            case "{": braces += 1
            case "}": braces -= 1
            case "(": parentheses += 1
            case ")": parentheses -= 1
            case _ where character.isLetter || character == "_":
                let end = document[index...].firstIndex { !($0.isLetter || $0.isNumber || $0 == "_") } ?? document.endIndex
                let preceding = index > document.startIndex ? document[document.index(before: index)] : " "
                let word = document[index..<end]
                if braces == 0, parentheses == 0, preceding != "$", preceding != "@",
                    word == "mutation" || word == "subscription"
                {
                    return true
                }
                index = end
                continue
            default: break
            }
            index = document.index(after: index)
        }
        return false
    }

    /// The index just past the string that starts at `start`, handling escapes and `"""` blocks.
    private static func endOfString(in document: String, from start: String.Index) -> String.Index {
        if document[start...].hasPrefix("\"\"\"") {
            // Block strings end at the first `"""` that isn't escaped as `\"""`.
            var index = document.index(start, offsetBy: 3)
            while index < document.endIndex {
                if document[index...].hasPrefix("\\\"\"\"") {
                    index = document.index(index, offsetBy: 4)
                } else if document[index...].hasPrefix("\"\"\"") {
                    return document.index(index, offsetBy: 3)
                } else {
                    index = document.index(after: index)
                }
            }
            return document.endIndex
        }
        var index = document.index(after: start)
        while index < document.endIndex {
            switch document[index] {
            case "\\": index = document.index(index, offsetBy: 2, limitedBy: document.endIndex) ?? document.endIndex
            case "\"": return document.index(after: index)
            default: index = document.index(after: index)
            }
        }
        return document.endIndex
    }
}
