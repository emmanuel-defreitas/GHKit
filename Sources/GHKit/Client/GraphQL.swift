import Foundation

/// One error from the GraphQL API.
public struct GraphQLError: Sendable, Hashable, Decodable, CustomStringConvertible {
    public var message: String
    /// GitHub's error type, such as `NOT_FOUND`, `FORBIDDEN`, or `RATE_LIMITED`.
    public var type: String?
    public var path: [JSONValue]?
    public var locations: [Location]?

    public struct Location: Sendable, Hashable, Decodable {
        public var line: Int
        public var column: Int
    }

    public var description: String { type.map { "\($0): \(message)" } ?? message }
}

/// Placeholder for operations that take no variables.
public struct NoVariables: Encodable, Sendable {
    public init() {}
}

extension GitHubClient {
    /// Runs a GraphQL query or mutation and decodes its `data` object.
    ///
    ///     struct Viewer: Decodable { struct User: Decodable { let login: String }; let viewer: User }
    ///     let result = try await github.graphQL("query { viewer { login } }", as: Viewer.self)
    ///
    /// Throws `GitHubError.graphQL` when the response has errors, even if partial data came back.
    public func graphQL<Value: Decodable & Sendable>(
        _ query: String,
        variables: some Encodable & Sendable = NoVariables(),
        as type: Value.Type = Value.self
    ) async throws(GitHubError) -> Value {
        let request = GitHubRequest<Value>(
            method: .post,
            target: .url(configuration.server.graphQLURL),
            body: .json(GraphQLBody(query: query, variables: variables)),
            decode: { data in
                let envelope = try GitHubJSON.decoder().decode(GraphQLEnvelope<Value>.self, from: data)
                if let errors = envelope.errors, !errors.isEmpty { throw GitHubError.graphQL(errors) }
                guard let value = envelope.data else { throw GitHubError.graphQL([]) }
                return value
            }
        )
        return try await value(request)
    }
}

private struct GraphQLBody<Variables: Encodable & Sendable>: Encodable, Sendable {
    let query: String
    let variables: Variables
}

private struct GraphQLEnvelope<Value: Decodable>: Decodable {
    let data: Value?
    let errors: [GraphQLError]?
}
