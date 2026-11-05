// GHKitCore: the client, HTTP, authentication, pagination, GraphQL, and the models
// that more than one domain module uses. Each domain (GHKitIssues, GHKitRepositories, …)
// adds its API to `GitHubClient`, and `import GHKit` brings in all of them:
//
//     let github = GitHubClient(token: "ghp_…")
//     let me = try await github.users.authenticated()   // GHKitUsers
//
// See README.md for authentication flows and TODO.md for API coverage.

/// The library version, sent in the default `User-Agent` header.
public enum GHKitVersion {
    public static let current = "0.4.0"
}
