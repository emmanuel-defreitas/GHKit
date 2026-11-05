import Foundation

extension GitHubClient {
    /// Current rate limits for every bucket. This call doesn't count against them.
    public func rateLimit() async throws(GitHubError) -> RateLimitOverview {
        try await value(GitHubRequest(.get, "/rate_limit"))
    }

    /// For "check" endpoints that answer `204` for yes and `404` for no.
    package func exists(_ path: String) async throws(GitHubError) -> Bool {
        do {
            try await value(GitHubRequest<Void>(.get, path))
            return true
        } catch .notFound(_, _) {
            return false
        }
    }
}
