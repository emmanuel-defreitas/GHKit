import Foundation
import GHKitCore

extension GitHubClient {
    /// Repository endpoints.
    public var repositories: RepositoriesAPI { RepositoriesAPI(client: scoped(to: .repositories)) }
}

/// Repository endpoints. Reach them with `github.repositories`.
///
/// Repositories are named by owner login and repository name, such as `("apple", "swift")`.
///
/// Part of the `GHKitRepositories` library.
public struct RepositoriesAPI: Sendable {
    let client: GitHubClient

    func path(_ owner: String, _ name: String, _ rest: String = "") -> String {
        "/repos/\(escape(owner))/\(escape(name))\(rest)"
    }

    // MARK: Repositories

    /// One repository, with its settings, license, and fork parent. `GET /repos/{owner}/{repo}`
    public func repository(_ owner: String, _ name: String) async throws(GitHubError) -> Repository {
        try await client.value(GitHubRequest(.get, path(owner, name)))
    }

    /// Creates a repository for the signed-in user. `POST /user/repos`
    @discardableResult
    public func create(_ repository: NewRepository) async throws(GitHubError) -> Repository {
        try await client.value(GitHubRequest(.post, "/user/repos", body: repository))
    }

    /// Creates a repository in an organization. `POST /orgs/{org}/repos`
    @discardableResult
    public func create(_ repository: NewRepository, in org: String) async throws(GitHubError) -> Repository {
        try await client.value(GitHubRequest(.post, "/orgs/\(escape(org))/repos", body: repository))
    }

    /// Changes a repository's settings. `PATCH /repos/{owner}/{repo}`
    @discardableResult
    public func update(_ owner: String, _ name: String, _ changes: RepositoryUpdate) async throws(GitHubError) -> Repository {
        try await client.value(GitHubRequest(.patch, path(owner, name), body: changes))
    }

    /// Deletes a repository. This can't be undone. `DELETE /repos/{owner}/{repo}`
    public func delete(_ owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name)))
    }

    /// Starts moving a repository to another user or organization. GitHub finishes in the background.
    /// `POST /repos/{owner}/{repo}/transfer`
    /// - Parameters:
    ///   - newName: Renames the repository on the way.
    ///   - teamIDs: Teams in the new organization to give access.
    @discardableResult
    public func transfer(
        _ owner: String, _ name: String, to newOwner: String, newName: String? = nil, teamIDs: [Int]? = nil
    ) async throws(GitHubError) -> Repository {
        struct Body: Encodable, Sendable {
            let newOwner: String
            let newName: String?
            let teamIDs: [Int]?
            enum CodingKeys: String, CodingKey {
                case newOwner = "new_owner"
                case newName = "new_name"
                case teamIDs = "team_ids"
            }
        }
        return try await client.value(
            GitHubRequest(.post, path(owner, name, "/transfer"), body: Body(newOwner: newOwner, newName: newName, teamIDs: teamIDs)))
    }

    // MARK: Lists

    /// Repositories the signed-in user can access. `GET /user/repos`
    public func list(
        matching filter: RepositoryFilter = RepositoryFilter(), sort: RepositorySort = .fullName, ascending: Bool? = nil,
        perPage: Int = 100
    ) -> Paginated<Repository> {
        client.paginate(GitHubRequest(.get, "/user/repos", query: filter.query + sortQuery(sort, ascending, perPage)))
    }

    /// A user's public repositories. `GET /users/{username}/repos`
    public func list(
        of login: String, type: UserRepositoryType = .owner, sort: RepositorySort = .fullName, ascending: Bool? = nil,
        perPage: Int = 100
    ) -> Paginated<Repository> {
        client.paginate(
            GitHubRequest(
                .get, "/users/\(escape(login))/repos", query: .query(("type", type)) + sortQuery(sort, ascending, perPage)))
    }

    /// An organization's repositories that the signed-in user can see. `GET /orgs/{org}/repos`
    public func list(
        in org: String, type: OrganizationRepositoryType = .all, sort: RepositorySort = .created, ascending: Bool? = nil,
        perPage: Int = 100
    ) -> Paginated<Repository> {
        client.paginate(
            GitHubRequest(.get, "/orgs/\(escape(org))/repos", query: .query(("type", type)) + sortQuery(sort, ascending, perPage)))
    }

    /// Every public repository, in creation order. `GET /repositories`
    /// - Parameter since: Only repositories with an ID greater than this.
    public func all(since: Int? = nil) -> Paginated<Repository> {
        client.paginate(GitHubRequest(.get, "/repositories", query: .query(("since", since))))
    }

    private func sortQuery(_ sort: RepositorySort, _ ascending: Bool?, _ perPage: Int) -> [URLQueryItem] {
        .query(("sort", sort), ("direction", ascending.map { $0 ? "asc" : "desc" }), ("per_page", perPage))
    }

    // MARK: Details

    /// The repository's topics. `GET /repos/{owner}/{repo}/topics`
    public func topics(_ owner: String, _ name: String) async throws(GitHubError) -> [String] {
        let response: Topics = try await client.value(GitHubRequest(.get, path(owner, name, "/topics")))
        return response.names
    }

    /// Replaces the repository's topics. Topics are lowercase, with hyphens. `PUT /repos/{owner}/{repo}/topics`
    @discardableResult
    public func replaceTopics(_ topics: [String], on owner: String, _ name: String) async throws(GitHubError) -> [String] {
        let response: Topics = try await client.value(GitHubRequest(.put, path(owner, name, "/topics"), body: Topics(names: topics)))
        return response.names
    }

    /// Bytes of code per language. `GET /repos/{owner}/{repo}/languages`
    public func languages(_ owner: String, _ name: String) async throws(GitHubError) -> [String: Int] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/languages")))
    }

    /// The repository's tags, newest first. `GET /repos/{owner}/{repo}/tags`
    public func tags(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<RepositoryTag> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/tags"), query: .query(("per_page", perPage))))
    }

    /// Teams with access to the repository. `GET /repos/{owner}/{repo}/teams`
    public func teams(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<Team> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/teams"), query: .query(("per_page", perPage))))
    }

    /// Contributors, most commits first. `GET /repos/{owner}/{repo}/contributors`
    /// - Parameter includeAnonymous: Adds commit authors without a GitHub account.
    public func contributors(
        _ owner: String, _ name: String, includeAnonymous: Bool = false, perPage: Int = 100
    ) -> Paginated<Contributor> {
        // An empty repository answers 204 with no body.
        client.paginate(
            GitHubRequest(
                method: .get, target: .path(path(owner, name, "/contributors")),
                query: .query(("anon", includeAnonymous ? "1" : nil), ("per_page", perPage))
            ) { data in
                data.isEmpty ? [] : try GitHubJSON.decoder().decode([Contributor].self, from: data)
            })
    }

    /// Pushes, branch changes, and merges, newest first. `GET /repos/{owner}/{repo}/activity`
    public func activity(
        _ owner: String, _ name: String, matching filter: RepositoryActivityFilter = RepositoryActivityFilter(),
        perPage: Int = 100
    ) -> Paginated<RepositoryActivity> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/activity"), query: filter.query(perPage: perPage)))
    }

    /// The repository's community health score and recommended files. `GET /repos/{owner}/{repo}/community/profile`
    public func communityProfile(_ owner: String, _ name: String) async throws(GitHubError) -> CommunityProfile {
        try await client.value(GitHubRequest(.get, path(owner, name, "/community/profile")))
    }

    /// Whether the repository uses SHA-1 or SHA-256 object IDs. `GET /repos/{owner}/{repo}/hash-algorithm`
    public func hashAlgorithm(_ owner: String, _ name: String) async throws(GitHubError) -> HashAlgorithm {
        struct Response: Decodable, Sendable {
            let hashAlgorithm: HashAlgorithm
            enum CodingKeys: String, CodingKey { case hashAlgorithm = "hash_algorithm" }
        }
        let response: Response = try await client.value(GitHubRequest(.get, path(owner, name, "/hash-algorithm")))
        return response.hashAlgorithm
    }
}

private struct Topics: Codable, Sendable { let names: [String] }

/// The hash function a repository uses for object IDs.
public struct HashAlgorithm: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let sha1: Self = "sha1"
    public static let sha256: Self = "sha256"
}
