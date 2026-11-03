import Foundation

extension GitHubClient {
    /// Pull request endpoints, including reviews, review comments, merging, and stacks.
    public var pullRequests: PullRequestsAPI { PullRequestsAPI(client: self) }
}

/// Pull request endpoints. Reach them with `github.pullRequests`.
///
/// Pull requests are named by number within a repository, such as `pullRequest(1347, in: "octocat", "Hello-World")`.
/// A pull request's labels, assignees, and conversation comments go through ``IssuesAPI``.
public struct PullRequestsAPI: Sendable {
    let client: GitHubClient

    private func path(_ owner: String, _ name: String, _ rest: String = "") -> String {
        "/repos/\(escape(owner))/\(escape(name))\(rest)"
    }

    private func pullPath(_ number: Int, _ owner: String, _ name: String, _ rest: String = "") -> String {
        path(owner, name, "/pulls/\(number)\(rest)")
    }

    private func sortQuery(_ sort: (any CustomStringConvertible)?, _ ascending: Bool?, _ perPage: Int) -> [URLQueryItem] {
        .query(("sort", sort), ("direction", ascending.map { $0 ? "asc" : "desc" }), ("per_page", perPage))
    }

    // MARK: Pull requests

    /// A repository's pull requests. `GET /repos/{owner}/{repo}/pulls`
    /// - Parameters:
    ///   - head: Only pull requests from this branch, as `owner:branch`.
    ///   - base: Only pull requests into this branch.
    public func list(
        _ owner: String, _ name: String, state: IssueStateFilter = .open, head: String? = nil, base: String? = nil,
        sort: PullRequestSort = .created, ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<PullRequest> {
        let query: [URLQueryItem] = .query(("state", state), ("head", head), ("base", base)) + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, path(owner, name, "/pulls"), query: query))
    }

    /// One pull request, with its merge status and counts. `GET /repos/{owner}/{repo}/pulls/{pull_number}`
    public func pullRequest(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequest {
        try await client.value(GitHubRequest(.get, pullPath(number, owner, name)))
    }

    /// A pull request's changes as a diff or patch. `GET /repos/{owner}/{repo}/pulls/{pull_number}` with a diff or patch media type
    public func diff(_ number: Int, in owner: String, _ name: String, format: DiffFormat = .diff) async throws(GitHubError) -> String {
        try await client.value(
            GitHubRequest(
                method: .get, target: .path(pullPath(number, owner, name)),
                headers: ["Accept": "application/vnd.github.\(format.rawValue)"]
            ) { String(decoding: $0, as: UTF8.self) })
    }

    /// Opens a pull request. `POST /repos/{owner}/{repo}/pulls`
    @discardableResult
    public func create(_ pullRequest: NewPullRequest, in owner: String, _ name: String) async throws(GitHubError) -> PullRequest {
        try await client.value(GitHubRequest(.post, path(owner, name, "/pulls"), body: pullRequest))
    }

    /// Changes a pull request's title, description, state, or base branch. `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
    @discardableResult
    public func update(
        _ number: Int, in owner: String, _ name: String, _ changes: PullRequestUpdate
    ) async throws(GitHubError) -> PullRequest {
        try await client.value(GitHubRequest(.patch, pullPath(number, owner, name), body: changes))
    }

    /// Closes a pull request without merging it. `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
    @discardableResult
    public func close(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequest {
        try await update(number, in: owner, name, PullRequestUpdate(state: .closed))
    }

    /// Reopens a closed pull request. `PATCH /repos/{owner}/{repo}/pulls/{pull_number}`
    @discardableResult
    public func reopen(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequest {
        try await update(number, in: owner, name, PullRequestUpdate(state: .open))
    }

    /// A pull request's commits, oldest first. At most 250. `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits`
    public func commits(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<Commit> {
        client.paginate(GitHubRequest(.get, pullPath(number, owner, name, "/commits"), query: .query(("per_page", perPage))))
    }

    /// The files a pull request changes. At most 3000. `GET /repos/{owner}/{repo}/pulls/{pull_number}/files`
    public func files(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<DiffEntry> {
        client.paginate(GitHubRequest(.get, pullPath(number, owner, name, "/files"), query: .query(("per_page", perPage))))
    }

    /// Pull requests that contain a commit: open ones that include it, or the merged one that introduced it.
    /// `GET /repos/{owner}/{repo}/commits/{commit_sha}/pulls`
    public func pullRequests(containing sha: String, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<PullRequest> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/commits/\(escape(sha))/pulls"), query: .query(("per_page", perPage))))
    }

    // MARK: Merging

    /// Whether a pull request was merged. `GET /repos/{owner}/{repo}/pulls/{pull_number}/merge`
    public func isMerged(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists(pullPath(number, owner, name, "/merge"))
    }

    /// Merges a pull request now. Fails with ``GitHubError/http(status:_:_:)`` `405` when it can't be merged,
    /// or `409` when ``MergeOptions/expectedHeadSHA`` no longer matches. `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge`
    @discardableResult
    public func merge(
        _ number: Int, in owner: String, _ name: String, _ options: MergeOptions = MergeOptions()
    ) async throws(GitHubError) -> MergeResult {
        try await client.value(GitHubRequest(.put, pullPath(number, owner, name, "/merge"), body: options))
    }

    /// Asks GitHub to merge a pull request in the background, directly or through the merge queue.
    /// Check on it with ``backgroundMerge(_:of:in:_:)``. `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge-async`
    /// - Parameter bypassRules: Merges despite rulesets, if you're allowed to bypass them.
    @discardableResult
    public func mergeInBackground(
        _ number: Int, in owner: String, _ name: String, _ options: MergeOptions = MergeOptions(), action: MergeAction? = nil,
        bypassRules: Bool? = nil
    ) async throws(GitHubError) -> BackgroundMerge {
        struct Body: Encodable, Sendable {
            let options: MergeOptions
            let action: MergeAction?
            let bypassRules: Bool?
            enum CodingKeys: String, CodingKey {
                case action = "merge_action"
                case bypassRules = "bypass_rules"
            }
            func encode(to encoder: any Encoder) throws {
                try options.encode(to: encoder)
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encodeIfPresent(action, forKey: .action)
                try c.encodeIfPresent(bypassRules, forKey: .bypassRules)
            }
        }
        return try await client.value(
            GitHubRequest(
                .put, pullPath(number, owner, name, "/merge-async"), body: Body(options: options, action: action, bypassRules: bypassRules)))
    }

    /// Where a background merge stands. `GET /repos/{owner}/{repo}/pulls/{pull_number}/merge-async/{uuid}`
    /// - Parameter uuid: From ``BackgroundMerge/Details/uuid``.
    public func backgroundMerge(_ uuid: String, of number: Int, in owner: String, _ name: String) async throws(GitHubError) -> BackgroundMerge {
        try await client.value(GitHubRequest(.get, pullPath(number, owner, name, "/merge-async/\(escape(uuid))")))
    }

    /// Merges the base branch into the head branch. GitHub finishes in the background.
    /// `PUT /repos/{owner}/{repo}/pulls/{pull_number}/update-branch`
    /// - Parameter expectedHeadSHA: Updates only if the head is still at this SHA.
    public func updateBranch(
        _ number: Int, in owner: String, _ name: String, expectedHeadSHA: String? = nil
    ) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let expectedHeadSHA: String?
            enum CodingKeys: String, CodingKey { case expectedHeadSHA = "expected_head_sha" }
        }
        try await client.value(
            GitHubRequest<Void>(.put, pullPath(number, owner, name, "/update-branch"), body: Body(expectedHeadSHA: expectedHeadSHA)))
    }

    // MARK: Review requests

    /// The people and teams asked to review, who haven't reviewed yet.
    /// `GET /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers`
    public func requestedReviewers(of number: Int, in owner: String, _ name: String) async throws(GitHubError) -> ReviewRequests {
        try await client.value(GitHubRequest(.get, pullPath(number, owner, name, "/requested_reviewers")))
    }

    /// Asks people and teams to review. `POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers`
    /// - Parameter teams: Team slugs.
    @discardableResult
    public func requestReviewers(
        _ logins: [String] = [], teams: [String] = [], on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequest {
        try await client.value(
            GitHubRequest(.post, pullPath(number, owner, name, "/requested_reviewers"), body: Reviewers(logins, teams)))
    }

    /// Withdraws review requests. `DELETE /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers`
    /// - Parameter teams: Team slugs.
    @discardableResult
    public func removeRequestedReviewers(
        _ logins: [String], teams: [String] = [], from number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequest {
        try await client.value(
            GitHubRequest(
                .delete, pullPath(number, owner, name, "/requested_reviewers"), body: Reviewers(logins, teams, alwaysSendLogins: true)))
    }

    /// Asks people and teams who already reviewed to review again.
    /// `POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers/rerequest`
    /// - Parameter teams: Team slugs.
    @discardableResult
    public func rerequestReviewers(
        _ logins: [String] = [], teams: [String] = [], on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequest {
        try await client.value(
            GitHubRequest(.post, pullPath(number, owner, name, "/requested_reviewers/rerequest"), body: Reviewers(logins, teams)))
    }

    private struct Reviewers: Encodable, Sendable {
        let reviewers: [String]?
        let teamReviewers: [String]?

        init(_ logins: [String], _ teams: [String], alwaysSendLogins: Bool = false) {
            reviewers = logins.isEmpty && !alwaysSendLogins ? nil : logins
            teamReviewers = teams.isEmpty ? nil : teams
        }

        enum CodingKeys: String, CodingKey {
            case reviewers
            case teamReviewers = "team_reviewers"
        }
    }

    // MARK: Reviews

    /// A pull request's reviews, oldest first. `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews`
    public func reviews(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<PullRequestReview> {
        client.paginate(GitHubRequest(.get, pullPath(number, owner, name, "/reviews"), query: .query(("per_page", perPage))))
    }

    /// One review. `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}`
    public func review(id: Int, of number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequestReview {
        try await client.value(GitHubRequest(.get, pullPath(number, owner, name, "/reviews/\(id)")))
    }

    /// Starts a review, or submits one in a single step when ``NewReview/event`` is set.
    /// `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews`
    @discardableResult
    public func createReview(
        _ review: NewReview, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequestReview {
        try await client.value(GitHubRequest(.post, pullPath(number, owner, name, "/reviews"), body: review))
    }

    /// Submits a pending review. `POST /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/events`
    /// - Parameter body: Required to request changes or comment.
    @discardableResult
    public func submitReview(
        id: Int, of number: Int, in owner: String, _ name: String, event: ReviewEvent, body: String? = nil
    ) async throws(GitHubError) -> PullRequestReview {
        struct Body: Encodable, Sendable {
            let event: ReviewEvent
            let body: String?
        }
        return try await client.value(
            GitHubRequest(.post, pullPath(number, owner, name, "/reviews/\(id)/events"), body: Body(event: event, body: body)))
    }

    /// Changes a review's summary. `PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}`
    @discardableResult
    public func updateReview(
        id: Int, of number: Int, in owner: String, _ name: String, body: String
    ) async throws(GitHubError) -> PullRequestReview {
        try await client.value(GitHubRequest(.put, pullPath(number, owner, name, "/reviews/\(id)"), body: ["body": body]))
    }

    /// Deletes a review that hasn't been submitted. `DELETE /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}`
    @discardableResult
    public func deletePendingReview(
        id: Int, of number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequestReview {
        try await client.value(GitHubRequest(.delete, pullPath(number, owner, name, "/reviews/\(id)")))
    }

    /// Dismisses a submitted review so it no longer counts. Needs admin access or branch protection that allows it.
    /// `PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals`
    @discardableResult
    public func dismissReview(
        id: Int, of number: Int, in owner: String, _ name: String, message: String
    ) async throws(GitHubError) -> PullRequestReview {
        struct Body: Encodable, Sendable {
            let message: String
            let event = "DISMISS"
        }
        return try await client.value(
            GitHubRequest(.put, pullPath(number, owner, name, "/reviews/\(id)/dismissals"), body: Body(message: message)))
    }

    /// The comments in one review. `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/comments`
    public func comments(
        inReview id: Int, of number: Int, in owner: String, _ name: String, perPage: Int = 100
    ) -> Paginated<ReviewComment> {
        client.paginate(GitHubRequest(.get, pullPath(number, owner, name, "/reviews/\(id)/comments"), query: .query(("per_page", perPage))))
    }

    // MARK: Review comments

    /// Comments on a pull request's diff. `GET /repos/{owner}/{repo}/pulls/{pull_number}/comments`
    /// - Parameter updatedSince: Only comments updated at or after this time.
    public func reviewComments(
        on number: Int, in owner: String, _ name: String, sort: IssueCommentSort = .created, ascending: Bool? = nil,
        updatedSince: Date? = nil, perPage: Int = 100
    ) -> Paginated<ReviewComment> {
        let query: [URLQueryItem] = .query(("since", updatedSince?.ISO8601Format())) + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, pullPath(number, owner, name, "/comments"), query: query))
    }

    /// Every review comment in a repository. `GET /repos/{owner}/{repo}/pulls/comments`
    /// - Parameter updatedSince: Only comments updated at or after this time.
    public func reviewComments(
        _ owner: String, _ name: String, sort: IssueCommentSort? = nil, ascending: Bool? = nil, updatedSince: Date? = nil,
        perPage: Int = 100
    ) -> Paginated<ReviewComment> {
        let query: [URLQueryItem] = .query(("since", updatedSince?.ISO8601Format())) + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, path(owner, name, "/pulls/comments"), query: query))
    }

    /// One review comment. `GET /repos/{owner}/{repo}/pulls/comments/{comment_id}`
    public func reviewComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> ReviewComment {
        try await client.value(GitHubRequest(.get, path(owner, name, "/pulls/comments/\(id)")))
    }

    /// Comments on the diff outside a review. ``NewReviewComment/commitID`` is required here.
    /// `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`
    @discardableResult
    public func createReviewComment(
        _ comment: NewReviewComment, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> ReviewComment {
        try await client.value(GitHubRequest(.post, pullPath(number, owner, name, "/comments"), body: comment))
    }

    /// Replies to a top-level review comment. `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies`
    @discardableResult
    public func replyToReviewComment(
        id: Int, on number: Int, in owner: String, _ name: String, body: String
    ) async throws(GitHubError) -> ReviewComment {
        try await client.value(GitHubRequest(.post, pullPath(number, owner, name, "/comments/\(id)/replies"), body: ["body": body]))
    }

    /// Changes a review comment's text. `PATCH /repos/{owner}/{repo}/pulls/comments/{comment_id}`
    @discardableResult
    public func updateReviewComment(id: Int, in owner: String, _ name: String, body: String) async throws(GitHubError) -> ReviewComment {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/pulls/comments/\(id)"), body: ["body": body]))
    }

    /// Deletes a review comment. `DELETE /repos/{owner}/{repo}/pulls/comments/{comment_id}`
    public func deleteReviewComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/pulls/comments/\(id)")))
    }

    // MARK: Stacks

    /// A repository's pull request stacks. `GET /repos/{owner}/{repo}/stacks`
    /// - Parameter pullRequest: Only the stack that holds this pull request.
    public func stacks(
        _ owner: String, _ name: String, containing pullRequest: Int? = nil, perPage: Int = 100
    ) -> Paginated<PullRequestStack> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/stacks"), query: .query(("pull_request", pullRequest), ("per_page", perPage))))
    }

    /// One stack, with its pull requests. `GET /repos/{owner}/{repo}/stacks/{stack_number}`
    public func stack(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequestStack {
        try await client.value(GitHubRequest(.get, path(owner, name, "/stacks/\(number)")))
    }

    /// Stacks pull requests, bottom first. Each one's base must be the head of the one before.
    /// `POST /repos/{owner}/{repo}/stacks`
    @discardableResult
    public func createStack(_ pullRequests: [Int], in owner: String, _ name: String) async throws(GitHubError) -> PullRequestStack {
        try await client.value(GitHubRequest(.post, path(owner, name, "/stacks"), body: ["pull_requests": pullRequests]))
    }

    /// Adds pull requests to the top of a stack. `POST /repos/{owner}/{repo}/stacks/{stack_number}/add`
    @discardableResult
    public func addToStack(
        _ pullRequests: [Int], stack number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> PullRequestStack {
        try await client.value(GitHubRequest(.post, path(owner, name, "/stacks/\(number)/add"), body: ["pull_requests": pullRequests]))
    }

    /// Takes the stack apart. Returns what's left, or `nil` once nothing is.
    /// `POST /repos/{owner}/{repo}/stacks/{stack_number}/unstack`
    @discardableResult
    public func unstack(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> PullRequestStack? {
        try await client.value(
            GitHubRequest(method: .post, target: .path(path(owner, name, "/stacks/\(number)/unstack"))) { data in
                data.isEmpty ? nil : try GitHubJSON.decoder().decode(PullRequestStack.self, from: data)
            })
    }
}

extension IssuesAPI {
    /// Everything that happened on an issue or pull request, oldest first: comments, commits, reviews, and events.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/timeline`
    /// - Parameter excluding: Kinds of entries to leave out, such as `.labeled`.
    public func timeline(
        of number: Int, in owner: String, _ name: String, excluding: [IssueEventType] = [], perPage: Int = 100
    ) -> Paginated<TimelineEvent> {
        let exclude = excluding.isEmpty ? nil : excluding.map(\.rawValue).joined(separator: ",")
        return client.paginate(
            GitHubRequest(.get, issuePath(number, owner, name, "/timeline"), query: .query(("exclude", exclude), ("per_page", perPage))))
    }
}
