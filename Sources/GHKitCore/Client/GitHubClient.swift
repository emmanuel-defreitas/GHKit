import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The entry point to the GitHub API.
///
/// `GitHubClient` is a lightweight `Sendable` value: copy it freely, store it in the
/// SwiftUI environment, and call it from any actor.
///
///     let github = GitHubClient(token: "ghp_…")
///     let me = try await github.users.authenticated()
public struct GitHubClient: Sendable {
    public let configuration: GitHubConfiguration
    public let authenticator: any Authenticator
    let transport: any HTTPTransport
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    /// The domain this client's requests belong to. API types set it with ``scoped(to:owner:)``.
    package var domain: GitHubDomain?
    /// The account this client's requests act on. It wins over the path, which can name the account by ID.
    package var owner: String?

    public init(
        authenticator: some Authenticator = AnonymousAuthenticator(),
        configuration: GitHubConfiguration = GitHubConfiguration(),
        transport: some HTTPTransport = URLSessionTransport()
    ) {
        self.authenticator = authenticator
        self.configuration = configuration
        self.transport = transport
    }

    /// A client that sends a personal access token, OAuth token, or installation token.
    public init(
        token: String,
        configuration: GitHubConfiguration = GitHubConfiguration(),
        transport: some HTTPTransport = URLSessionTransport()
    ) {
        self.init(authenticator: TokenAuthenticator(token: token), configuration: configuration, transport: transport)
    }

    /// A copy of this client that authenticates differently.
    public func with(authenticator: some Authenticator) -> GitHubClient {
        var copy = GitHubClient(authenticator: authenticator, configuration: configuration, transport: transport)
        copy.sleep = sleep
        copy.domain = domain
        copy.owner = owner
        return copy
    }

    /// A copy whose requests are tagged with `domain` and `owner`, so a ``RoutedAuthenticator`` can pick a
    /// credential for them.
    package func scoped(to domain: GitHubDomain, owner: String? = nil) -> GitHubClient {
        var copy = self
        copy.domain = domain
        copy.owner = owner ?? self.owner
        return copy
    }

    /// What `request` is about, for ``Authenticator/authenticator(for:)``.
    /// The request's own domain and owner come first, then this client's, then the owner in the path.
    package func context<Response>(for request: GitHubRequest<Response>) -> GitHubRequestContext {
        GitHubRequestContext(
            domain: request.domain ?? domain,
            owner: request.routingOwner ?? owner ?? request.pathOwner,
            method: request.method
        )
    }

    /// `request` tagged with this client's domain and owner, for API types that hand requests out.
    package func tagged<Response>(_ request: GitHubRequest<Response>) -> GitHubRequest<Response> {
        var copy = request
        copy.domain = copy.domain ?? domain
        copy.routingOwner = copy.routingOwner ?? owner
        return copy
    }
}

// MARK: - Sending

extension GitHubClient {
    /// Sends a request and returns the decoded value with its response metadata.
    ///
    /// Handles authentication, a single token refresh after a `401`, and retries
    /// for rate limits and server errors as set in `configuration.retryPolicy`.
    public func send<Response>(_ request: GitHubRequest<Response>) async throws(GitHubError) -> GitHubResponse<Response> {
        let policy = configuration.retryPolicy
        var attempt = 0
        var refreshedCredentials = false

        let authenticator = self.authenticator.authenticator(for: context(for: request))

        while true {
            if Task.isCancelled { throw .cancelled }

            var urlRequest = try makeURLRequest(for: request)
            if let authorization = try await authenticator.authorization() {
                urlRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
            }

            let (data, http) = try await perform(urlRequest)
            let metadata = ResponseMetadata(http)
            configuration.onResponse?(metadata)

            if (200..<300).contains(http.statusCode) {
                let value = try await Self.decode(data, with: request.decode)
                return GitHubResponse(value: value, metadata: metadata)
            }

            if http.statusCode == 401, !refreshedCredentials,
                try await authenticator.refreshAfterUnauthorized()
            {
                refreshedCredentials = true
                continue
            }

            let error = GitHubError.from(status: http.statusCode, data: data, metadata: metadata)
            guard attempt < policy.maxRetries, let delay = retryDelay(for: error, method: request.method, attempt: attempt) else {
                throw error
            }
            attempt += 1
            do { try await sleep(delay) } catch { throw .cancelled }
        }
    }

    /// Sends a request and returns only the decoded value.
    public func value<Response>(_ request: GitHubRequest<Response>) async throws(GitHubError) -> Response {
        try await send(request).value
    }

    private func perform(_ request: URLRequest) async throws(GitHubError) -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch is CancellationError {
            throw .cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw .cancelled
        } catch let error as GitHubError {
            throw error
        } catch {
            throw .transport(error)
        }
    }

    /// Decodes off the caller's actor, so large payloads don't block the main thread.
    @concurrent
    private static func decode<Response: Sendable>(
        _ data: Data,
        with decode: @Sendable (Data) throws -> Response
    ) async throws(GitHubError) -> Response {
        do {
            return try decode(data)
        } catch let error as GitHubError {
            throw error
        } catch {
            throw .decoding(type: String(describing: Response.self), underlying: error)
        }
    }

    private func retryDelay(for error: GitHubError, method: HTTPMethod, attempt: Int) -> Duration? {
        let policy = configuration.retryPolicy
        switch error {
        case .rateLimited(_, let retryAfter?, _, _):
            return retryAfter <= policy.maxDelay ? retryAfter : nil
        case .http(let status, _, _) where policy.retryableStatusCodes.contains(status) && method.isIdempotent:
            let delay = policy.baseDelay * (1 << attempt)
            return min(delay, policy.maxDelay)
        default:
            return nil
        }
    }

    func makeURLRequest<Response>(for request: GitHubRequest<Response>) throws(GitHubError) -> URLRequest {
        let base: URL =
            switch request.target {
            case .path: configuration.server.apiURL
            case .url(let url): url
            }
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw .invalidRequest("Invalid URL: \(base)")
        }
        if case .path(let path) = request.target {
            // Wrapped endpoints escape each segment already, and `URL.appending(path:)` would
            // encode them a second time. `encodePath` keeps those escapes and encodes anything
            // else a path can't hold, which `percentEncodedPath` would otherwise trap on.
            var basePath = components.percentEncodedPath
            if basePath.hasSuffix("/") { basePath.removeLast() }
            components.percentEncodedPath = basePath + encodePath(path)
        }
        if !request.query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + request.query
            // URLComponents leaves "+" alone, but GitHub reads it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw .invalidRequest("Invalid URL: \(components)") }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(configuration.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        urlRequest.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        switch request.body {
        case .json(let body)?:
            do {
                urlRequest.httpBody = try GitHubJSON.encoder().encode(body)
            } catch {
                throw .invalidRequest("Couldn't encode the request body: \(error)")
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form(let fields)?:
            urlRequest.httpBody = Data(FormEncoding.encode(fields).utf8)
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        case .raw(let data, let contentType)?:
            urlRequest.httpBody = data
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        case nil:
            break
        }

        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        return urlRequest
    }
}

enum FormEncoding {
    static func encode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return
            fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }
}
