import Foundation

/// A typed description of one API call. Build your own to reach endpoints GHKit doesn't wrap yet:
///
///     let request = GitHubRequest<[Label]>(.get, "/repos/\(owner)/\(repo)/labels")
///     let labels = try await github.send(request).value
public struct GitHubRequest<Response: Sendable>: Sendable {
    public enum Target: Sendable, Hashable {
        /// A path relative to the server's REST base URL, such as `/user`.
        case path(String)
        /// An absolute URL, used for GraphQL and for following pagination links.
        case url(URL)
    }

    public var method: HTTPMethod
    public var target: Target
    public var query: [URLQueryItem]
    public var headers: [String: String]
    public var body: RequestBody?
    let decode: @Sendable (Data) throws -> Response

    public init(
        method: HTTPMethod,
        target: Target,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: RequestBody? = nil,
        decode: @escaping @Sendable (Data) throws -> Response
    ) {
        self.method = method
        self.target = target
        self.query = query
        self.headers = headers
        self.body = body
        self.decode = decode
    }

    /// The same request pointed at a different URL. The decoder is kept.
    func redirected(to url: URL) -> GitHubRequest {
        var copy = self
        copy.target = .url(url)
        copy.query = []
        return copy
    }
}

/// A request body.
public enum RequestBody: Sendable {
    case json(any Encodable & Sendable)
    case form([String: String])
    case raw(Data, contentType: String)
}

extension GitHubRequest where Response: Decodable {
    /// A request whose JSON response decodes into `Response`.
    public init(
        _ method: HTTPMethod,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil
    ) {
        self.init(
            method: method,
            target: .path(path),
            query: query,
            body: body.map { .json($0) },
            decode: { data in try GitHubJSON.decoder().decode(Response.self, from: data) }
        )
    }
}

extension GitHubRequest where Response == Void {
    /// A request whose response body is ignored, such as a `204 No Content`.
    public init(
        _ method: HTTPMethod,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable & Sendable)? = nil
    ) {
        self.init(method: method, target: .path(path), query: query, body: body.map { .json($0) }, decode: { _ in })
    }
}

/// Percent-encodes one path segment, such as a login or a branch name.
func escape(_ segment: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/?#")
    return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
}

extension Array where Element == URLQueryItem {
    /// Builds query items, dropping `nil` values.
    static func query(_ pairs: (String, (any CustomStringConvertible)?)...) -> [URLQueryItem] {
        pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0.description) } }
    }
}
