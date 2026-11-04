import Foundation

/// The GitHub deployment a client talks to.
public struct GitHubServer: Sendable, Hashable {
    /// Base URL for REST calls, such as `https://api.github.com`.
    public var apiURL: URL
    /// Endpoint for GraphQL calls.
    public var graphQLURL: URL
    /// Base URL for the website, used for OAuth (`/login/oauth/...`).
    public var webURL: URL
    /// Base URL for file uploads, such as release assets.
    public var uploadsURL: URL

    /// - Parameter uploadsURL: Defaults to `uploads.` in place of `api.` in the API host, or `api/uploads` on the website.
    public init(apiURL: URL, graphQLURL: URL, webURL: URL, uploadsURL: URL? = nil) {
        self.apiURL = apiURL
        self.graphQLURL = graphQLURL
        self.webURL = webURL
        self.uploadsURL = uploadsURL ?? Self.defaultUploadsURL(apiURL: apiURL, webURL: webURL)
    }

    private static func defaultUploadsURL(apiURL: URL, webURL: URL) -> URL {
        if var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false),
            let host = components.host, host.hasPrefix("api.")
        {
            components.host = "uploads." + host.dropFirst("api.".count)
            components.path = ""
            if let url = components.url { return url }
        }
        return webURL.appending(path: "api/uploads")
    }

    /// github.com
    public static let dotCom = GitHubServer(
        apiURL: URL(string: "https://api.github.com")!,
        graphQLURL: URL(string: "https://api.github.com/graphql")!,
        webURL: URL(string: "https://github.com")!,
        uploadsURL: URL(string: "https://uploads.github.com")!
    )

    /// GitHub Enterprise Server at `host`, for example `https://github.example.com`.
    public static func enterpriseServer(_ host: URL) -> GitHubServer {
        GitHubServer(
            apiURL: host.appending(path: "api/v3"),
            graphQLURL: host.appending(path: "api/graphql"),
            webURL: host,
            uploadsURL: host.appending(path: "api/uploads")
        )
    }

    /// GitHub Enterprise Cloud with data residency (`SUBDOMAIN.ghe.com`).
    public static func enterpriseCloud(subdomain: String) -> GitHubServer {
        GitHubServer(
            apiURL: URL(string: "https://api.\(subdomain).ghe.com")!,
            graphQLURL: URL(string: "https://api.\(subdomain).ghe.com/graphql")!,
            webURL: URL(string: "https://\(subdomain).ghe.com")!,
            uploadsURL: URL(string: "https://uploads.\(subdomain).ghe.com")!
        )
    }
}

/// When the client retries a failed request.
public struct RetryPolicy: Sendable, Hashable {
    /// Retries after the first attempt. `0` turns retries off.
    public var maxRetries: Int
    /// Longest wait the client accepts before a retry, for example after a rate limit.
    public var maxDelay: Duration
    /// First backoff delay for server errors. It doubles on each retry.
    public var baseDelay: Duration
    /// Server errors that are retried for idempotent methods.
    public var retryableStatusCodes: Set<Int>

    public init(
        maxRetries: Int = 2,
        maxDelay: Duration = .seconds(60),
        baseDelay: Duration = .seconds(1),
        retryableStatusCodes: Set<Int> = [500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.maxDelay = maxDelay
        self.baseDelay = baseDelay
        self.retryableStatusCodes = retryableStatusCodes
    }

    public static let `default` = RetryPolicy()
    public static let none = RetryPolicy(maxRetries: 0)
}

/// Client-wide settings.
public struct GitHubConfiguration: Sendable {
    public var server: GitHubServer
    /// Value of the `X-GitHub-Api-Version` header.
    public var apiVersion: String
    public var userAgent: String
    public var retryPolicy: RetryPolicy
    /// Called after every HTTP response, for example to show rate limits in the UI.
    /// It runs on the task that made the request; hop to the main actor yourself if needed.
    public var onResponse: (@Sendable (ResponseMetadata) -> Void)?

    public init(
        server: GitHubServer = .dotCom,
        apiVersion: String = "2022-11-28",
        userAgent: String = "GHKit/\(GHKitVersion.current)",
        retryPolicy: RetryPolicy = .default,
        onResponse: (@Sendable (ResponseMetadata) -> Void)? = nil
    ) {
        self.server = server
        self.apiVersion = apiVersion
        self.userAgent = userAgent
        self.retryPolicy = retryPolicy
        self.onResponse = onResponse
    }
}
