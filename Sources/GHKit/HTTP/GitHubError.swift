import Foundation

/// Every error GHKit throws. All public async APIs use `throws(GitHubError)`,
/// so a `catch` can switch over these cases exhaustively.
public enum GitHubError: Error, Sendable {
    /// The task was cancelled.
    case cancelled
    /// The request never got a response, for example because the device is offline.
    case transport(any Error)
    /// GHKit couldn't build the request.
    case invalidRequest(String)
    /// `304 Not Modified` after a conditional request.
    case notModified(ResponseMetadata)
    /// `401`: the credentials are missing, wrong, or expired.
    case unauthorized(APIErrorResponse?, ResponseMetadata)
    /// `403`: the credentials lack permission (and it isn't a rate limit).
    case forbidden(APIErrorResponse?, ResponseMetadata)
    /// `404`: missing, or hidden from these credentials.
    case notFound(APIErrorResponse?, ResponseMetadata)
    /// `422`: GitHub rejected the input.
    case validationFailed(APIErrorResponse?, ResponseMetadata)
    /// A primary or secondary rate limit was hit.
    case rateLimited(RateLimit?, retryAfter: Duration?, APIErrorResponse?, ResponseMetadata)
    /// Any other non-success status.
    case http(status: Int, APIErrorResponse?, ResponseMetadata)
    /// The response didn't match the expected shape.
    case decoding(type: String, underlying: any Error)
    /// The GraphQL API returned errors.
    case graphQL([GraphQLError])
    /// An OAuth endpoint returned an error, such as `access_denied` or `expired_token`.
    case oauth(OAuthError)
    /// A local authentication problem, such as an unreadable private key or a state mismatch.
    case authentication(String)
}

extension GitHubError {
    /// The HTTP status code, when the error came from a response.
    public var statusCode: Int? { metadata?.statusCode }

    /// Response details, when the error came from a response.
    public var metadata: ResponseMetadata? {
        switch self {
        case .notModified(let m): m
        case .unauthorized(_, let m), .forbidden(_, let m), .notFound(_, let m), .validationFailed(_, let m): m
        case .rateLimited(_, _, _, let m): m
        case .http(_, _, let m): m
        default: nil
        }
    }

    /// GitHub's error body, when there is one.
    public var apiError: APIErrorResponse? {
        switch self {
        case .unauthorized(let e, _), .forbidden(let e, _), .notFound(let e, _), .validationFailed(let e, _): e
        case .rateLimited(_, _, let e, _): e
        case .http(_, let e, _): e
        default: nil
        }
    }

    static func from(status: Int, data: Data, metadata: ResponseMetadata) -> GitHubError {
        let body = try? GitHubJSON.decoder().decode(APIErrorResponse.self, from: data)
        let rateLimit = metadata.rateLimit
        let mentionsRateLimit = body?.message.localizedCaseInsensitiveContains("rate limit") ?? false

        if status == 429 || (status == 403 && (rateLimit?.isExhausted == true || metadata.retryAfter != nil || mentionsRateLimit)) {
            var retryAfter = metadata.retryAfter
            if retryAfter == nil, let rateLimit, rateLimit.isExhausted {
                retryAfter = .seconds(max(0, Int(rateLimit.reset.timeIntervalSinceNow.rounded(.up))))
            }
            return .rateLimited(rateLimit, retryAfter: retryAfter, body, metadata)
        }

        return switch status {
        case 304: .notModified(metadata)
        case 401: .unauthorized(body, metadata)
        case 403: .forbidden(body, metadata)
        case 404: .notFound(body, metadata)
        case 422: .validationFailed(body, metadata)
        default: .http(status: status, body, metadata)
        }
    }
}

extension GitHubError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled: "The request was cancelled."
        case .transport(let error): "Network error: \(error.localizedDescription)"
        case .invalidRequest(let reason): "Invalid request: \(reason)"
        case .notModified: "Not modified."
        case .unauthorized(let e, _): e?.message ?? "Authentication is required."
        case .forbidden(let e, _): e?.message ?? "You don't have permission to do that."
        case .notFound(let e, _): e?.message ?? "Not found."
        case .validationFailed(let e, _): e?.summary ?? "GitHub rejected the request."
        case .rateLimited(let limit, _, let e, _):
            e?.message ?? limit.map { "Rate limit exceeded. Resets at \($0.reset.formatted())." } ?? "Rate limit exceeded."
        case .http(let status, let e, _): e?.message ?? "GitHub returned HTTP \(status)."
        case .decoding(let type, let error): "Couldn't read \(type) from the response: \(error)"
        case .graphQL(let errors): errors.map(\.message).joined(separator: "\n")
        case .oauth(let error): error.errorDescription
        case .authentication(let reason): reason
        }
    }
}

/// GitHub's JSON error body.
public struct APIErrorResponse: Sendable, Hashable, Decodable {
    public var message: String
    public var documentationURL: URL?
    public var status: String?
    public var errors: [Detail]?

    /// One validation problem. GitHub sends either an object or a bare string.
    public struct Detail: Sendable, Hashable, Decodable {
        public var resource: String?
        public var field: String?
        public var code: String?
        public var message: String?

        private enum CodingKeys: String, CodingKey { case resource, field, code, message }

        public init(from decoder: any Decoder) throws {
            if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
                message = text
                return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            resource = try c.decodeIfPresent(String.self, forKey: .resource)
            field = try c.decodeIfPresent(String.self, forKey: .field)
            code = try c.decodeIfPresent(String.self, forKey: .code)
            message = try c.decodeIfPresent(String.self, forKey: .message)
        }
    }

    /// The message plus each validation detail, on one line.
    public var summary: String {
        let details = (errors ?? []).compactMap { $0.message ?? [$0.resource, $0.field, $0.code].compactMap(\.self).joined(separator: " ") }
        return ([message] + details).joined(separator: " — ")
    }

    private enum CodingKeys: String, CodingKey {
        case message, status, errors
        case documentationURL = "documentation_url"
    }
}
