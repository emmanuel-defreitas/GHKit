import Foundation

/// A typed description of one API call. Build your own to reach endpoints GHKit doesn't wrap yet:
///
///     let request = GitHubRequest<[Label]>(.get, "/repos/\(owner)/\(repo)/labels")
///     let labels = try await github.send(request).value
///
/// Characters a URL path can't hold, such as spaces, are percent-encoded when the request is sent.
/// Existing `%XX` escapes are kept as they are, so a path may be escaped already or not at all.
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
    /// The page size of a list endpoint that pages by number but sends no `Link` header.
    /// A full page then means there may be another.
    package var numberedPageSize: Int?
    /// The part of the API the request belongs to, for credential routing. Requests an API type hands out,
    /// such as `ProjectsAPI.itemsRequest(of:)`, carry it so they route the same way when sent from any client.
    package var domain: GitHubDomain?
    /// The account the request acts on, when the path can't tell. Next-page links can name a repository by
    /// ID instead of owner, so they keep the first page's owner.
    package var routingOwner: String?

    /// The user or organization login in the path, such as `"acme"` in `/repos/acme/app/issues`.
    /// Absolute URLs, such as release upload addresses, are searched too, so a server prefix like
    /// `/api/uploads` doesn't hide the owner.
    package var pathOwner: String? {
        let parts: [String]
        switch target {
        case .path(let path):
            parts = path.split(separator: "/").map(String.init)
            guard parts.count >= 2, ownerSegments.contains(parts[0]) else { return nil }
            return parts[1].removingPercentEncoding ?? parts[1]
        case .url(let url):
            parts = url.pathComponents.filter { $0 != "/" }
            guard let index = parts.firstIndex(where: ownerSegments.contains), index + 1 < parts.count else {
                return nil
            }
            return parts[index + 1]
        }
    }

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
        copy.routingOwner = routingOwner ?? pathOwner
        copy.target = .url(url)
        copy.query = []
        return copy
    }
}

/// Path segments followed by an account login.
private let ownerSegments: Set<String> = ["repos", "orgs", "users"]

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
package func escape(_ segment: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/?#")
    return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
}

/// Percent-encodes what a URL path can't hold, keeping `%XX` escapes that are already there.
///
/// Wrapped endpoints escape each segment with `escape(_:)`. Custom requests may pass raw text.
package func encodePath(_ path: String) -> String {
    let scalars = Array(path.unicodeScalars)
    var result = path.hasPrefix("/") ? "" : "/"
    var index = 0
    while index < scalars.count {
        let scalar = scalars[index]
        if scalar == "%", index + 2 < scalars.count,
            scalars[index + 1].properties.isASCIIHexDigit, scalars[index + 2].properties.isASCIIHexDigit
        {
            result.unicodeScalars.append(contentsOf: scalars[index...(index + 2)])
            index += 3
            continue
        }
        if CharacterSet.urlPathAllowed.contains(scalar) {
            result.unicodeScalars.append(scalar)
        } else {
            result += String(scalar).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        }
        index += 1
    }
    return result
}

extension Array where Element == URLQueryItem {
    /// Builds query items, dropping `nil` values.
    package static func query(_ pairs: (String, (any CustomStringConvertible)?)...) -> [URLQueryItem] {
        pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0.description) } }
    }
}
