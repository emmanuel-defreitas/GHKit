import Foundation
import GHKitCore

extension GitHubClient {
    /// Gist endpoints.
    public var gists: GistsAPI { GistsAPI(client: self) }
}

/// Gist endpoints. Reach them with `github.gists`.
///
///     let gist = try await github.gists.create(NewGist(description: "Notes", files: ["notes.md": "# Hello"]))
///     try await github.gists.update(id: gist.id, GistUpdate(files: ["notes.md": .rename(to: "README.md")]))
///
/// Part of the `GHKitGists` library.
public struct GistsAPI: Sendable {
    let client: GitHubClient

    private func path(_ id: String, _ rest: String = "") -> String {
        "/gists/\(escape(id))\(rest)"
    }

    // MARK: Gists

    /// Gists, newest first. `GET /gists`, `GET /users/{username}/gists`, `GET /gists/public`, or `GET /gists/starred`,
    /// depending on `collection`.
    /// - Parameter since: Only gists updated at or after this time.
    public func list(_ collection: GistCollection = .signedInUser, since: Date? = nil, perPage: Int = 100) -> Paginated<Gist> {
        client.paginate(
            GitHubRequest(.get, collection.path, query: .query(("since", since?.ISO8601Format()), ("per_page", perPage))))
    }

    /// One gist with its files' contents, or one of its earlier revisions.
    /// `GET /gists/{gist_id}`, or `GET /gists/{gist_id}/{sha}` when you pass a revision.
    /// - Parameter revision: A ``GistCommit/version``, or `nil` for the latest.
    public func gist(id: String, revision: String? = nil) async throws(GitHubError) -> Gist {
        try await client.value(GitHubRequest(.get, path(id, revision.map { "/\(escape($0))" } ?? "")))
    }

    /// Creates a gist as the signed-in user. `POST /gists`
    @discardableResult
    public func create(_ gist: NewGist) async throws(GitHubError) -> Gist {
        try await client.value(GitHubRequest(.post, "/gists", body: gist))
    }

    /// Changes a gist's description or files. `PATCH /gists/{gist_id}`
    @discardableResult
    public func update(id: String, _ update: GistUpdate) async throws(GitHubError) -> Gist {
        try await client.value(GitHubRequest(.patch, path(id), body: update))
    }

    /// Deletes a gist. `DELETE /gists/{gist_id}`
    public func delete(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(id)))
    }

    /// A gist's revisions, newest first. `GET /gists/{gist_id}/commits`
    public func commits(of id: String, perPage: Int = 100) -> Paginated<GistCommit> {
        client.paginate(GitHubRequest(.get, path(id, "/commits"), query: .query(("per_page", perPage))))
    }

    /// Forks of a gist. `GET /gists/{gist_id}/forks`
    public func forks(of id: String, perPage: Int = 100) -> Paginated<Gist> {
        client.paginate(GitHubRequest(.get, path(id, "/forks"), query: .query(("per_page", perPage))))
    }

    /// Forks a gist to the signed-in user. `POST /gists/{gist_id}/forks`
    @discardableResult
    public func fork(id: String) async throws(GitHubError) -> Gist {
        try await client.value(GitHubRequest(.post, path(id, "/forks")))
    }

    // MARK: Stars

    /// Whether the signed-in user starred a gist. `GET /gists/{gist_id}/star`
    public func isStarred(id: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(id, "/star"))
    }

    /// Stars a gist as the signed-in user. `PUT /gists/{gist_id}/star`
    public func star(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(id, "/star")))
    }

    /// Removes the signed-in user's star. `DELETE /gists/{gist_id}/star`
    public func unstar(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(id, "/star")))
    }

    // MARK: Comments

    /// A gist's comments, oldest first. `GET /gists/{gist_id}/comments`
    public func comments(on id: String, perPage: Int = 100) -> Paginated<GistComment> {
        client.paginate(GitHubRequest(.get, path(id, "/comments"), query: .query(("per_page", perPage))))
    }

    /// One comment. `GET /gists/{gist_id}/comments/{comment_id}`
    public func comment(id: Int, on gistID: String) async throws(GitHubError) -> GistComment {
        try await client.value(GitHubRequest(.get, path(gistID, "/comments/\(id)")))
    }

    /// Comments on a gist. `POST /gists/{gist_id}/comments`
    @discardableResult
    public func createComment(_ body: String, on gistID: String) async throws(GitHubError) -> GistComment {
        try await client.value(GitHubRequest(.post, path(gistID, "/comments"), body: ["body": body]))
    }

    /// Changes a comment's text. `PATCH /gists/{gist_id}/comments/{comment_id}`
    @discardableResult
    public func updateComment(id: Int, on gistID: String, body: String) async throws(GitHubError) -> GistComment {
        try await client.value(GitHubRequest(.patch, path(gistID, "/comments/\(id)"), body: ["body": body]))
    }

    /// Deletes a comment. `DELETE /gists/{gist_id}/comments/{comment_id}`
    public func deleteComment(id: Int, on gistID: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(gistID, "/comments/\(id)")))
    }
}
