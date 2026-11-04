import Foundation
import GHKitCore

extension GitHubClient {
    /// Issue endpoints, including labels, milestones, assignees, and comments.
    public var issues: IssuesAPI { IssuesAPI(client: self) }
}

/// Issue endpoints. Reach them with `github.issues`.
///
/// Issues are named by number within a repository, such as `issue(1347, in: "octocat", "Hello-World")`.
/// Pull requests are issues too, so these endpoints also work on a pull request's labels, assignees, and conversation.
///
/// Part of the `GHKitIssues` library.
public struct IssuesAPI: Sendable {
    let client: GitHubClient

    func path(_ owner: String, _ name: String, _ rest: String = "") -> String {
        "/repos/\(escape(owner))/\(escape(name))\(rest)"
    }

    func issuePath(_ number: Int, _ owner: String, _ name: String, _ rest: String = "") -> String {
        path(owner, name, "/issues/\(number)\(rest)")
    }

    private func sortQuery(_ sort: (any CustomStringConvertible)?, _ ascending: Bool?, _ perPage: Int) -> [URLQueryItem] {
        .query(("sort", sort), ("direction", ascending.map { $0 ? "asc" : "desc" }), ("per_page", perPage))
    }

    // MARK: Issues

    /// Issues that involve the signed-in user, across repositories.
    /// `GET /issues`, `GET /user/issues`, or `GET /orgs/{org}/issues`, depending on `scope`.
    public func list(
        _ relationship: IssueRelationship = .assigned, in scope: IssueScope = .everywhere, matching filter: IssueFilter = IssueFilter(),
        sort: IssueSort = .created, ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<GitHubIssue> {
        let path: String
        let isOrganization: Bool
        switch scope {
        case .everywhere: (path, isOrganization) = ("/issues", false)
        case .personalRepositories: (path, isOrganization) = ("/user/issues", false)
        case .organization(let org): (path, isOrganization) = ("/orgs/\(escape(org))/issues", true)
        }
        let query: [URLQueryItem] =
            .query(("filter", relationship)) + filter.query(repository: false, organization: isOrganization)
            + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, path, query: query))
    }

    /// A repository's issues and pull requests. `GET /repos/{owner}/{repo}/issues`
    public func list(
        _ owner: String, _ name: String, matching filter: IssueFilter = IssueFilter(), sort: IssueSort = .created,
        ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<GitHubIssue> {
        let query = filter.query(repository: true, organization: false) + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, path(owner, name, "/issues"), query: query))
    }

    /// One issue or pull request. `GET /repos/{owner}/{repo}/issues/{issue_number}`
    public func issue(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.get, issuePath(number, owner, name)))
    }

    /// Opens an issue. `POST /repos/{owner}/{repo}/issues`
    @discardableResult
    public func create(_ issue: NewIssue, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.post, path(owner, name, "/issues"), body: issue))
    }

    /// Changes an issue. `PATCH /repos/{owner}/{repo}/issues/{issue_number}`
    @discardableResult
    public func update(_ number: Int, in owner: String, _ name: String, _ changes: IssueUpdate) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.patch, issuePath(number, owner, name), body: changes))
    }

    /// Closes an issue. `PATCH /repos/{owner}/{repo}/issues/{issue_number}`
    @discardableResult
    public func close(
        _ number: Int, in owner: String, _ name: String, reason: IssueStateReason = .completed
    ) async throws(GitHubError) -> GitHubIssue {
        try await update(number, in: owner, name, IssueUpdate(state: .closed, stateReason: reason))
    }

    /// Reopens a closed issue. `PATCH /repos/{owner}/{repo}/issues/{issue_number}`
    @discardableResult
    public func reopen(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await update(number, in: owner, name, IssueUpdate(state: .open))
    }

    /// Locks the conversation so only collaborators can comment. `PUT /repos/{owner}/{repo}/issues/{issue_number}/lock`
    public func lock(_ number: Int, in owner: String, _ name: String, reason: LockReason? = nil) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let lockReason: LockReason?
            enum CodingKeys: String, CodingKey { case lockReason = "lock_reason" }
        }
        try await client.value(GitHubRequest<Void>(.put, issuePath(number, owner, name, "/lock"), body: Body(lockReason: reason)))
    }

    /// Unlocks the conversation. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/lock`
    public func unlock(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, issuePath(number, owner, name, "/lock")))
    }

    // MARK: Assignees

    /// People who can be assigned to issues in a repository. `GET /repos/{owner}/{repo}/assignees`
    public func assignees(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/assignees"), query: .query(("per_page", perPage))))
    }

    /// Whether someone can be assigned to issues in a repository. `GET /repos/{owner}/{repo}/assignees/{assignee}`
    public func canAssign(_ login: String, in owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(owner, name, "/assignees/\(escape(login))"))
    }

    /// Whether someone can be assigned to one issue.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/assignees/{assignee}`
    public func canAssign(_ login: String, to number: Int, in owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists(issuePath(number, owner, name, "/assignees/\(escape(login))"))
    }

    /// Adds assignees, keeping the current ones. An issue has at most 10.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/assignees`
    @discardableResult
    public func addAssignees(_ logins: [String], to number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/assignees"), body: ["assignees": logins]))
    }

    /// Removes assignees. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/assignees`
    @discardableResult
    public func removeAssignees(
        _ logins: [String], from number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.delete, issuePath(number, owner, name, "/assignees"), body: ["assignees": logins]))
    }

    // MARK: Comments

    /// Comments on an issue or pull request conversation, oldest first.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/comments`
    /// - Parameter updatedSince: Only comments updated at or after this time.
    public func comments(
        on number: Int, in owner: String, _ name: String, updatedSince: Date? = nil, perPage: Int = 100
    ) -> Paginated<IssueComment> {
        client.paginate(
            GitHubRequest(
                .get, issuePath(number, owner, name, "/comments"),
                query: .query(("since", updatedSince?.ISO8601Format()), ("per_page", perPage))))
    }

    /// Every issue and pull request comment in a repository. `GET /repos/{owner}/{repo}/issues/comments`
    /// - Parameter updatedSince: Only comments updated at or after this time.
    public func comments(
        _ owner: String, _ name: String, sort: IssueCommentSort = .created, ascending: Bool? = nil, updatedSince: Date? = nil,
        perPage: Int = 100
    ) -> Paginated<IssueComment> {
        let query: [URLQueryItem] = .query(("since", updatedSince?.ISO8601Format())) + sortQuery(sort, ascending, perPage)
        return client.paginate(GitHubRequest(.get, path(owner, name, "/issues/comments"), query: query))
    }

    /// One comment. `GET /repos/{owner}/{repo}/issues/comments/{comment_id}`
    public func comment(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> IssueComment {
        try await client.value(GitHubRequest(.get, path(owner, name, "/issues/comments/\(id)")))
    }

    /// Comments on an issue or pull request. `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`
    @discardableResult
    public func createComment(_ body: String, on number: Int, in owner: String, _ name: String) async throws(GitHubError) -> IssueComment {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/comments"), body: ["body": body]))
    }

    /// Changes a comment's text. `PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}`
    @discardableResult
    public func updateComment(id: Int, in owner: String, _ name: String, body: String) async throws(GitHubError) -> IssueComment {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/issues/comments/\(id)"), body: ["body": body]))
    }

    /// Deletes a comment. `DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}`
    public func deleteComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/issues/comments/\(id)")))
    }

    /// Pins a comment to the top of its conversation. `PUT /repos/{owner}/{repo}/issues/comments/{comment_id}/pin`
    @discardableResult
    public func pinComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> IssueComment {
        try await client.value(GitHubRequest(.put, path(owner, name, "/issues/comments/\(id)/pin")))
    }

    /// Unpins a comment. `DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}/pin`
    public func unpinComment(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/issues/comments/\(id)/pin")))
    }

    // MARK: Labels

    /// A repository's labels. `GET /repos/{owner}/{repo}/labels`
    public func labels(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueLabel> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/labels"), query: .query(("per_page", perPage))))
    }

    /// One label. `GET /repos/{owner}/{repo}/labels/{name}`
    public func label(named label: String, in owner: String, _ name: String) async throws(GitHubError) -> IssueLabel {
        try await client.value(GitHubRequest(.get, path(owner, name, "/labels/\(escape(label))")))
    }

    /// Creates a label. `POST /repos/{owner}/{repo}/labels`
    @discardableResult
    public func createLabel(_ label: NewLabel, in owner: String, _ name: String) async throws(GitHubError) -> IssueLabel {
        try await client.value(GitHubRequest(.post, path(owner, name, "/labels"), body: label))
    }

    /// Renames, recolors, describes, or archives a label. `PATCH /repos/{owner}/{repo}/labels/{name}`
    @discardableResult
    public func updateLabel(
        named label: String, in owner: String, _ name: String, _ changes: LabelUpdate
    ) async throws(GitHubError) -> IssueLabel {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/labels/\(escape(label))"), body: changes))
    }

    /// Deletes a label and removes it from every issue. `DELETE /repos/{owner}/{repo}/labels/{name}`
    public func deleteLabel(named label: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/labels/\(escape(label))")))
    }

    /// The labels on an issue or pull request. `GET /repos/{owner}/{repo}/issues/{issue_number}/labels`
    public func labels(on number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueLabel> {
        client.paginate(GitHubRequest(.get, issuePath(number, owner, name, "/labels"), query: .query(("per_page", perPage))))
    }

    /// Adds labels, keeping the current ones. Returns every label on the issue.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/labels`
    @discardableResult
    public func addLabels(
        _ labels: [String], to number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> [IssueLabel] {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/labels"), body: ["labels": labels]))
    }

    /// Replaces every label. An empty array removes them all. `PUT /repos/{owner}/{repo}/issues/{issue_number}/labels`
    @discardableResult
    public func setLabels(
        _ labels: [String], on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> [IssueLabel] {
        try await client.value(GitHubRequest(.put, issuePath(number, owner, name, "/labels"), body: ["labels": labels]))
    }

    /// Removes one label. Returns the labels left on the issue.
    /// `DELETE /repos/{owner}/{repo}/issues/{issue_number}/labels/{name}`
    @discardableResult
    public func removeLabel(
        named label: String, from number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> [IssueLabel] {
        try await client.value(GitHubRequest(.delete, issuePath(number, owner, name, "/labels/\(escape(label))")))
    }

    /// Removes every label. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/labels`
    public func removeAllLabels(from number: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, issuePath(number, owner, name, "/labels")))
    }

    /// The labels on a milestone's issues. `GET /repos/{owner}/{repo}/milestones/{milestone_number}/labels`
    public func labels(inMilestone number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueLabel> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/milestones/\(number)/labels"), query: .query(("per_page", perPage))))
    }

    // MARK: Milestones

    /// A repository's milestones. `GET /repos/{owner}/{repo}/milestones`
    public func milestones(
        _ owner: String, _ name: String, state: IssueStateFilter = .open, sort: MilestoneSort = .dueOn, ascending: Bool? = nil,
        perPage: Int = 100
    ) -> Paginated<Milestone> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/milestones"), query: .query(("state", state)) + sortQuery(sort, ascending, perPage)))
    }

    /// One milestone. `GET /repos/{owner}/{repo}/milestones/{milestone_number}`
    public func milestone(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) -> Milestone {
        try await client.value(GitHubRequest(.get, path(owner, name, "/milestones/\(number)")))
    }

    /// Creates a milestone. `POST /repos/{owner}/{repo}/milestones`
    @discardableResult
    public func createMilestone(_ milestone: NewMilestone, in owner: String, _ name: String) async throws(GitHubError) -> Milestone {
        try await client.value(GitHubRequest(.post, path(owner, name, "/milestones"), body: milestone))
    }

    /// Changes a milestone. `PATCH /repos/{owner}/{repo}/milestones/{milestone_number}`
    @discardableResult
    public func updateMilestone(
        _ number: Int, in owner: String, _ name: String, _ changes: MilestoneUpdate
    ) async throws(GitHubError) -> Milestone {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/milestones/\(number)"), body: changes))
    }

    /// Deletes a milestone. Its issues stay open. `DELETE /repos/{owner}/{repo}/milestones/{milestone_number}`
    public func deleteMilestone(_ number: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/milestones/\(number)")))
    }
}
