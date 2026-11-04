import Foundation
import GHKitCore

extension GitHubClient {
    /// Reaction endpoints.
    public var reactions: ReactionsAPI { ReactionsAPI(client: self) }
}

/// Reaction endpoints. Reach them with `github.reactions`.
///
/// Each method takes a ``ReactionSubject``, such as `.issue(1347)` or `.reviewComment(id: 10)`.
/// The counts are on the subject itself, such as ``GitHubIssue/reactions``.
///
/// Part of the `GHKitIssues` library.
public struct ReactionsAPI: Sendable {
    let client: GitHubClient

    private func path(_ subject: ReactionSubject, _ owner: String, _ name: String, _ rest: String = "") -> String {
        "/repos/\(escape(owner))/\(escape(name))\(subject.path)\(rest)"
    }

    /// The reactions on an issue, pull request, comment, or release.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/reactions` and the same path under each kind of subject
    /// - Parameter content: Only this reaction.
    public func list(
        on subject: ReactionSubject, in owner: String, _ name: String, content: ReactionContent? = nil, perPage: Int = 100
    ) -> Paginated<Reaction> {
        client.paginate(GitHubRequest(.get, path(subject, owner, name), query: .query(("content", content), ("per_page", perPage))))
    }

    /// Reacts as the signed-in user. Reacting the same way twice returns the existing reaction.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/reactions` and the same path under each kind of subject
    @discardableResult
    public func add(
        _ content: ReactionContent, to subject: ReactionSubject, in owner: String, _ name: String
    ) async throws(GitHubError) -> Reaction {
        try await client.value(GitHubRequest(.post, path(subject, owner, name), body: ["content": content]))
    }

    /// Removes a reaction. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/reactions/{reaction_id}`
    /// and the same path under each kind of subject
    public func delete(id: Int, from subject: ReactionSubject, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(subject, owner, name, "/\(id)")))
    }
}
