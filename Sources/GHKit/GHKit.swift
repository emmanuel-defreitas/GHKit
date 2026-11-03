// GHKit: a Swift-concurrency-first client for the GitHub REST and GraphQL APIs.
//
// Start with `GitHubClient`:
//
//     let github = GitHubClient(token: "ghp_…")
//     let me = try await github.users.authenticated()
//
//     let acme = github.projects(.organization("acme"))
//     for try await project in acme.list() {
//         print(project.number, project.title)
//     }
//
// See README.md for authentication flows and TODO.md for API coverage.

/// The library version, sent in the default `User-Agent` header.
public enum GHKitVersion {
    public static let current = "0.2.0"
}
