import Foundation

// Commits, comparisons, commit comments, and commit statuses.
extension RepositoriesAPI {
    // MARK: Commits

    /// A repository's commits, newest first. `GET /repos/{owner}/{repo}/commits`
    /// - Parameters:
    ///   - ref: A branch, tag, or SHA to start from. Defaults to the default branch.
    ///   - path: Only commits that touch this file or directory.
    ///   - author: Only commits by this login or email.
    ///   - committer: Only commits committed by this login or email.
    public func commits(
        _ owner: String, _ name: String, ref: String? = nil, path filePath: String? = nil, author: String? = nil,
        committer: String? = nil, since: Date? = nil, until: Date? = nil, perPage: Int = 100
    ) -> Paginated<Commit> {
        client.paginate(
            GitHubRequest(
                .get, path(owner, name, "/commits"),
                query: .query(
                    ("sha", ref), ("path", filePath), ("author", author), ("committer", committer), ("since", since?.ISO8601Format()),
                    ("until", until?.ISO8601Format()), ("per_page", perPage))))
    }

    /// One commit with its changed files (up to 300). `GET /repos/{owner}/{repo}/commits/{ref}`
    public func commit(_ ref: String, in owner: String, _ name: String) async throws(GitHubError) -> Commit {
        try await client.value(GitHubRequest(.get, commitPath(owner, name, ref)))
    }

    /// A commit as a diff or patch. `GET /repos/{owner}/{repo}/commits/{ref}` with a diff or patch media type
    public func commitDiff(_ ref: String, in owner: String, _ name: String, format: DiffFormat = .diff) async throws(GitHubError) -> String {
        try await text(commitPath(owner, name, ref), accept: "application/vnd.github.\(format.rawValue)")
    }

    /// The full SHA a branch, tag, or short SHA points to. `GET /repos/{owner}/{repo}/commits/{ref}` with the SHA media type
    public func commitSHA(for ref: String, in owner: String, _ name: String) async throws(GitHubError) -> String {
        try await text(commitPath(owner, name, ref), accept: "application/vnd.github.sha")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitPath(_ owner: String, _ name: String, _ ref: String) -> String {
        path(owner, name, "/commits/\(escapePath(ref))")
    }

    private func text(_ path: String, accept: String) async throws(GitHubError) -> String {
        try await client.value(
            GitHubRequest(method: .get, target: .path(path), headers: ["Accept": accept]) { String(decoding: $0, as: UTF8.self) })
    }

    // MARK: Comparisons

    /// How `head` relates to `base`, with the commits and files between them.
    /// `GET /repos/{owner}/{repo}/compare/{base}...{head}`
    /// - Parameters:
    ///   - base: A branch, tag, or SHA. Use `owner:branch` to compare across forks.
    ///   - head: A branch, tag, or SHA. Use `owner:branch` to compare across forks.
    public func compare(_ base: String, _ head: String, in owner: String, _ name: String) async throws(GitHubError) -> CommitComparison {
        try await client.value(GitHubRequest(.get, comparePath(owner, name, base, head)))
    }

    /// Every commit between two refs, oldest first, page by page.
    /// ``compare(_:_:in:_:)`` returns at most 250; use this when ``CommitComparison/totalCommits`` is larger.
    /// `GET /repos/{owner}/{repo}/compare/{base}...{head}`
    public func comparedCommits(_ base: String, _ head: String, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<Commit> {
        client.paginate(.wrappedList(comparePath(owner, name, base, head), key: "commits", query: .query(("per_page", perPage))))
    }

    /// The changes between two refs as a diff or patch.
    /// `GET /repos/{owner}/{repo}/compare/{base}...{head}` with a diff or patch media type
    public func compareDiff(
        _ base: String, _ head: String, in owner: String, _ name: String, format: DiffFormat = .diff
    ) async throws(GitHubError) -> String {
        try await text(comparePath(owner, name, base, head), accept: "application/vnd.github.\(format.rawValue)")
    }

    private func comparePath(_ owner: String, _ name: String, _ base: String, _ head: String) -> String {
        path(owner, name, "/compare/\(escapePath(base))...\(escapePath(head))")
    }

    // MARK: Commit comments

    /// Every commit comment in a repository, oldest first. `GET /repos/{owner}/{repo}/comments`
    public func commitComments(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<CommitComment> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/comments"), query: .query(("per_page", perPage))))
    }

    /// The comments on one commit. `GET /repos/{owner}/{repo}/commits/{commit_sha}/comments`
    public func comments(onCommit sha: String, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<CommitComment> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/commits/\(escape(sha))/comments"), query: .query(("per_page", perPage))))
    }

    /// One commit comment. `GET /repos/{owner}/{repo}/comments/{comment_id}`
    public func commitComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> CommitComment {
        try await client.value(GitHubRequest(.get, path(owner, name, "/comments/\(id)")))
    }

    /// Comments on a commit, or on one line of its diff. `POST /repos/{owner}/{repo}/commits/{commit_sha}/comments`
    /// - Parameters:
    ///   - path: The file to comment on.
    ///   - position: The line's index in the diff. Needs `path`.
    @discardableResult
    public func createCommitComment(
        _ body: String, on sha: String, in owner: String, _ name: String, path filePath: String? = nil, position: Int? = nil
    ) async throws(GitHubError) -> CommitComment {
        struct Body: Encodable, Sendable {
            let body: String
            let path: String?
            let position: Int?
        }
        return try await client.value(
            GitHubRequest(
                .post, path(owner, name, "/commits/\(escape(sha))/comments"), body: Body(body: body, path: filePath, position: position)))
    }

    /// Changes a commit comment's text. `PATCH /repos/{owner}/{repo}/comments/{comment_id}`
    @discardableResult
    public func updateCommitComment(id: Int, in owner: String, _ name: String, body: String) async throws(GitHubError) -> CommitComment {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/comments/\(id)"), body: ["body": body]))
    }

    /// Deletes a commit comment. `DELETE /repos/{owner}/{repo}/comments/{comment_id}`
    public func deleteCommitComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/comments/\(id)")))
    }

    // MARK: Statuses

    /// Every status reported on a ref, newest first. `GET /repos/{owner}/{repo}/commits/{ref}/statuses`
    public func statuses(for ref: String, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<CommitStatus> {
        client.paginate(GitHubRequest(.get, commitPath(owner, name, ref) + "/statuses", query: .query(("per_page", perPage))))
    }

    /// The latest status for each context on a ref, and the overall state. `GET /repos/{owner}/{repo}/commits/{ref}/status`
    public func combinedStatus(for ref: String, in owner: String, _ name: String, perPage: Int = 100) async throws(GitHubError)
        -> CombinedStatus
    {
        try await client.value(GitHubRequest(.get, commitPath(owner, name, ref) + "/status", query: .query(("per_page", perPage))))
    }

    /// Reports a status on a commit. A repository can hold up to 1000 statuses per SHA and context.
    /// `POST /repos/{owner}/{repo}/statuses/{sha}`
    @discardableResult
    public func createStatus(
        _ status: NewCommitStatus, on sha: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> CommitStatus {
        try await client.value(GitHubRequest(.post, path(owner, name, "/statuses/\(escape(sha))"), body: status))
    }
}
