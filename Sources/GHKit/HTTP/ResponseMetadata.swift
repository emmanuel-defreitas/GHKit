import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// A decoded value plus the response details that came with it.
public struct GitHubResponse<Value: Sendable>: Sendable {
    public var value: Value
    public var metadata: ResponseMetadata
}

/// Status, headers, and the GitHub-specific details parsed from them.
public struct ResponseMetadata: Sendable {
    public var statusCode: Int
    /// Header values keyed by lowercased name.
    public var headers: [String: String]
    public var url: URL?

    public init(statusCode: Int, headers: [String: String], url: URL? = nil) {
        self.statusCode = statusCode
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        self.url = url
    }

    init(_ response: HTTPURLResponse) {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String { headers[key.lowercased()] = "\(value)" }
        }
        self.init(statusCode: response.statusCode, headers: headers, url: response.url)
    }

    public subscript(header name: String) -> String? { headers[name.lowercased()] }

    public var rateLimit: RateLimit? { RateLimit(headers: headers) }
    public var links: LinkHeader { LinkHeader(self[header: "link"] ?? "") }
    public var etag: String? { self[header: "etag"] }
    public var requestID: String? { self[header: "x-github-request-id"] }

    /// Scopes granted to the OAuth token or classic PAT used for the request.
    public var oauthScopes: [OAuthScope]? {
        self[header: "x-oauth-scopes"].map(OAuthScope.parseList)
    }

    /// Scopes the endpoint accepts.
    public var acceptedOAuthScopes: [OAuthScope]? {
        self[header: "x-accepted-oauth-scopes"].map(OAuthScope.parseList)
    }

    /// When the token used for the request expires, if it does.
    public var tokenExpiration: Date? {
        guard let raw = self[header: "github-authentication-token-expiration"] else { return nil }
        // GitHub sends "2026-11-30 12:00:00 UTC"; rewrite it as ISO 8601.
        let iso =
            raw
            .replacingOccurrences(of: " UTC", with: "Z")
            .replacingOccurrences(of: " ", with: "T")
        return GitHubJSON.parseDate(iso)
    }

    /// Seconds from the `Retry-After` header.
    public var retryAfter: Duration? {
        self[header: "retry-after"].flatMap(Int.init).map { .seconds($0) }
    }
}

/// Rate limit details from `X-RateLimit-*` headers or from `GET /rate_limit`.
public struct RateLimit: Sendable, Hashable, Decodable {
    public var limit: Int
    public var remaining: Int
    public var used: Int
    /// When the current window resets.
    public var reset: Date
    /// Which bucket the limit applies to, such as `core`, `search`, or `graphql`.
    public var resource: String?

    public init(limit: Int, remaining: Int, used: Int, reset: Date, resource: String? = nil) {
        self.limit = limit
        self.remaining = remaining
        self.used = used
        self.reset = reset
        self.resource = resource
    }

    init?(headers: [String: String]) {
        guard let limit = headers["x-ratelimit-limit"].flatMap(Int.init),
            let remaining = headers["x-ratelimit-remaining"].flatMap(Int.init),
            let reset = headers["x-ratelimit-reset"].flatMap(TimeInterval.init)
        else { return nil }
        self.init(
            limit: limit,
            remaining: remaining,
            used: headers["x-ratelimit-used"].flatMap(Int.init) ?? (limit - remaining),
            reset: Date(timeIntervalSince1970: reset),
            resource: headers["x-ratelimit-resource"]
        )
    }

    public var isExhausted: Bool { remaining <= 0 }

    private enum CodingKeys: String, CodingKey { case limit, remaining, used, reset, resource }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        limit = try c.decode(Int.self, forKey: .limit)
        remaining = try c.decode(Int.self, forKey: .remaining)
        used = try c.decodeIfPresent(Int.self, forKey: .used) ?? (limit - remaining)
        reset = Date(timeIntervalSince1970: try c.decode(TimeInterval.self, forKey: .reset))
        resource = try c.decodeIfPresent(String.self, forKey: .resource)
    }
}

/// A parsed RFC 8288 `Link` header, as used for pagination.
public struct LinkHeader: Sendable, Hashable {
    public private(set) var links: [String: URL] = [:]

    public init(_ header: String) {
        var index = header.startIndex
        while let open = header[index...].firstIndex(of: "<"),
            let close = header[open...].firstIndex(of: ">")
        {
            let url = URL(string: String(header[header.index(after: open)..<close]))
            // Parameters run until the next link starts.
            let paramsEnd = header[close...].firstIndex(of: "<") ?? header.endIndex
            let params = header[header.index(after: close)..<paramsEnd]
            if let url, let rel = Self.relation(in: params) {
                for name in rel.split(separator: " ") { links[String(name)] = url }
            }
            index = paramsEnd
        }
    }

    public var next: URL? { links["next"] }
    public var previous: URL? { links["prev"] }
    public var first: URL? { links["first"] }
    public var last: URL? { links["last"] }

    private static func relation(in params: Substring) -> String? {
        for param in params.split(separator: ";") {
            let pair = param.split(separator: "=", maxSplits: 1)
            guard pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces) == "rel" else { continue }
            return pair[1]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\","))
        }
        return nil
    }
}
