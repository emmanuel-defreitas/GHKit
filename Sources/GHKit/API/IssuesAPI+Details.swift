import Foundation

extension IssuesAPI {
    // MARK: Events

    /// Every issue and pull request event in a repository, newest first. `GET /repos/{owner}/{repo}/issues/events`
    public func events(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueEvent> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/issues/events"), query: .query(("per_page", perPage))))
    }

    /// One event. `GET /repos/{owner}/{repo}/issues/events/{event_id}`
    public func event(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> IssueEvent {
        try await client.value(GitHubRequest(.get, path(owner, name, "/issues/events/\(id)")))
    }

    /// The events on one issue or pull request, oldest first. `GET /repos/{owner}/{repo}/issues/{issue_number}/events`
    public func events(on number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueEvent> {
        client.paginate(GitHubRequest(.get, issuePath(number, owner, name, "/events"), query: .query(("per_page", perPage))))
    }

    // MARK: Sub-issues

    /// The issue's parent, or `nil` if it isn't a sub-issue. `GET /repos/{owner}/{repo}/issues/{issue_number}/parent`
    public func parent(of number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue? {
        do {
            return try await client.value(GitHubRequest(.get, issuePath(number, owner, name, "/parent")))
        } catch .notFound(_, _) {
            return nil
        }
    }

    /// An issue's sub-issues, in order. `GET /repos/{owner}/{repo}/issues/{issue_number}/sub_issues`
    public func subIssues(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<GitHubIssue> {
        client.paginate(GitHubRequest(.get, issuePath(number, owner, name, "/sub_issues"), query: .query(("per_page", perPage))))
    }

    /// Makes an issue a sub-issue of this one. Returns the parent.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/sub_issues`
    /// - Parameters:
    ///   - id: The sub-issue's ``GitHubIssue/id``, not its number.
    ///   - replaceParent: Moves the issue here if it already has another parent. Without it, that fails.
    @discardableResult
    public func addSubIssue(
        id: Int, to number: Int, in owner: String, _ name: String, replaceParent: Bool = false
    ) async throws(GitHubError) -> GitHubIssue {
        struct Body: Encodable, Sendable {
            let subIssueID: Int
            let replaceParent: Bool?
            enum CodingKeys: String, CodingKey {
                case subIssueID = "sub_issue_id"
                case replaceParent = "replace_parent"
            }
        }
        return try await client.value(
            GitHubRequest(
                .post, issuePath(number, owner, name, "/sub_issues"),
                body: Body(subIssueID: id, replaceParent: replaceParent ? true : nil)))
    }

    /// Removes a sub-issue from this issue. Returns the parent. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/sub_issue`
    /// - Parameter id: The sub-issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func removeSubIssue(id: Int, from number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.delete, issuePath(number, owner, name, "/sub_issue"), body: ["sub_issue_id": id]))
    }

    /// Moves a sub-issue to another place among its siblings. Returns the parent.
    /// `PATCH /repos/{owner}/{repo}/issues/{issue_number}/sub_issues/priority`
    /// - Parameter id: The sub-issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func moveSubIssue(
        id: Int, _ position: SubIssuePosition, of number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> GitHubIssue {
        struct Body: Encodable, Sendable {
            let subIssueID: Int
            let afterID: Int?
            let beforeID: Int?
            enum CodingKeys: String, CodingKey {
                case subIssueID = "sub_issue_id"
                case afterID = "after_id"
                case beforeID = "before_id"
            }
        }
        let body: Body =
            switch position {
            case .after(let other): Body(subIssueID: id, afterID: other, beforeID: nil)
            case .before(let other): Body(subIssueID: id, afterID: nil, beforeID: other)
            }
        return try await client.value(GitHubRequest(.patch, issuePath(number, owner, name, "/sub_issues/priority"), body: body))
    }

    // MARK: Dependencies

    /// Issues that block this one. `GET /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by`
    public func blockers(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<GitHubIssue> {
        client.paginate(
            GitHubRequest(.get, issuePath(number, owner, name, "/dependencies/blocked_by"), query: .query(("per_page", perPage))))
    }

    /// Issues this one blocks. `GET /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocking`
    public func blockedIssues(by number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<GitHubIssue> {
        client.paginate(
            GitHubRequest(.get, issuePath(number, owner, name, "/dependencies/blocking"), query: .query(("per_page", perPage))))
    }

    /// Marks this issue as blocked by another. Returns the blocking issue.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by`
    /// - Parameter id: The blocking issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func addBlocker(id: Int, to number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(
            GitHubRequest(.post, issuePath(number, owner, name, "/dependencies/blocked_by"), body: ["issue_id": id]))
    }

    /// Stops another issue from blocking this one. Returns the issue that was blocking.
    /// `DELETE /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by/{issue_id}`
    /// - Parameter id: The blocking issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func removeBlocker(id: Int, from number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.delete, issuePath(number, owner, name, "/dependencies/blocked_by/\(id)")))
    }

    // MARK: Related issues

    /// Issues marked as related to this one. `GET /repos/{owner}/{repo}/issues/{issue_number}/relates_to`
    public func relatedIssues(to number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<GitHubIssue> {
        client.paginate(GitHubRequest(.get, issuePath(number, owner, name, "/relates_to"), query: .query(("per_page", perPage))))
    }

    /// Marks another issue as related. Returns the related issue.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/relates_to`
    /// - Parameter id: The related issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func addRelatedIssue(id: Int, to number: Int, in owner: String, _ name: String) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/relates_to"), body: ["issue_id": id]))
    }

    /// Removes a related issue. Returns the issue that was related.
    /// `DELETE /repos/{owner}/{repo}/issues/{issue_number}/relates_to/{issue_id}`
    /// - Parameter id: The related issue's ``GitHubIssue/id``, not its number.
    @discardableResult
    public func removeRelatedIssue(
        id: Int, from number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> GitHubIssue {
        try await client.value(GitHubRequest(.delete, issuePath(number, owner, name, "/relates_to/\(id)")))
    }

    // MARK: Field values

    /// The issue's custom field values. `GET /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values`
    public func fieldValues(of number: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<IssueFieldValue> {
        client.paginate(
            GitHubRequest(.get, issuePath(number, owner, name, "/issue-field-values"), query: .query(("per_page", perPage))))
    }

    /// Sets some field values, keeping the others. At most 25 per call. Returns every value on the issue.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values`
    @discardableResult
    public func addFieldValues(
        _ values: [NewIssueFieldValue], to number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> [IssueFieldValue] {
        try await client.value(
            GitHubRequest(.post, issuePath(number, owner, name, "/issue-field-values"), body: ["issue_field_values": values]))
    }

    /// Replaces every field value. An empty array clears them all.
    /// `PUT /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values`
    @discardableResult
    public func setFieldValues(
        _ values: [NewIssueFieldValue], on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> [IssueFieldValue] {
        try await client.value(
            GitHubRequest(.put, issuePath(number, owner, name, "/issue-field-values"), body: ["issue_field_values": values]))
    }

    /// Clears one field's value. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/issue-field-values/{issue_field_id}`
    public func deleteFieldValue(fieldID: Int, from number: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, issuePath(number, owner, name, "/issue-field-values/\(fieldID)")))
    }

    // MARK: Suggestions

    /// Changes GitHub suggests for an issue. `GET /repos/{owner}/{repo}/issues/{issue_number}/suggestions`
    /// - Parameter state: `nil` lists suggestions in every state.
    public func suggestions(
        for number: Int, in owner: String, _ name: String, state: IssueSuggestionState? = .pending,
        action: IssueSuggestionAction? = nil, perPage: Int = 100
    ) -> Paginated<IssueSuggestion> {
        client.paginate(
            GitHubRequest(
                .get, issuePath(number, owner, name, "/suggestions"),
                query: .query(("state", state?.rawValue ?? "all"), ("action", action), ("per_page", perPage))))
    }

    /// Approves and applies a suggestion.
    /// `POST /repos/{owner}/{repo}/issues/{issue_number}/suggestions/{suggestion_id}/approve`
    @discardableResult
    public func approveSuggestion(
        id: Int, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> IssueSuggestion {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/suggestions/\(id)/approve")))
    }

    /// Dismisses a suggestion. `POST /repos/{owner}/{repo}/issues/{issue_number}/suggestions/{suggestion_id}/dismiss`
    @discardableResult
    public func dismissSuggestion(
        id: Int, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> IssueSuggestion {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/suggestions/\(id)/dismiss")))
    }

    // MARK: Artifacts

    /// Documents attached to an issue. `GET /repos/{owner}/{repo}/issues/{issue_number}/artifacts`
    public func artifacts(
        on number: Int, in owner: String, _ name: String, type: IssueArtifactType? = nil, perPage: Int = 100
    ) -> Paginated<IssueArtifact> {
        // This endpoint sends no `Link` header, so pages are counted instead.
        var request = GitHubRequest<[IssueArtifact]>(
            .get, issuePath(number, owner, name, "/artifacts"), query: .query(("type", type), ("per_page", perPage)))
        request.numberedPageSize = perPage
        return client.paginate(request)
    }

    /// One artifact and its earlier versions.
    /// `GET /repos/{owner}/{repo}/issues/{issue_number}/artifacts/{artifact_number}`
    public func artifact(
        _ artifact: Int, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> IssueArtifactHistory {
        try await client.value(GitHubRequest(.get, issuePath(number, owner, name, "/artifacts/\(artifact)")))
    }

    /// Attaches a document to an issue. `POST /repos/{owner}/{repo}/issues/{issue_number}/artifacts`
    @discardableResult
    public func createArtifact(
        _ artifact: NewIssueArtifact, on number: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> IssueArtifact {
        try await client.value(GitHubRequest(.post, issuePath(number, owner, name, "/artifacts"), body: artifact))
    }

    /// Renames an artifact or replaces its content, keeping the old version.
    /// `PATCH /repos/{owner}/{repo}/issues/{issue_number}/artifacts/{artifact_number}`
    @discardableResult
    public func updateArtifact(
        _ artifact: Int, on number: Int, in owner: String, _ name: String, name newName: String? = nil, body: String? = nil
    ) async throws(GitHubError) -> IssueArtifact {
        struct Body: Encodable, Sendable {
            let name: String?
            let body: String?
        }
        return try await client.value(
            GitHubRequest(.patch, issuePath(number, owner, name, "/artifacts/\(artifact)"), body: Body(name: newName, body: body)))
    }

    /// Deletes an artifact. `DELETE /repos/{owner}/{repo}/issues/{issue_number}/artifacts/{artifact_number}`
    public func deleteArtifact(_ artifact: Int, on number: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, issuePath(number, owner, name, "/artifacts/\(artifact)")))
    }

    // MARK: Issue types

    /// The issue types available in a repository. `GET /repos/{owner}/{repo}/issue-types`
    public func types(_ owner: String, _ name: String) async throws(GitHubError) -> [IssueType] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/issue-types")))
    }

    /// An organization's issue types. `GET /orgs/{org}/issue-types`
    public func types(in org: String) async throws(GitHubError) -> [IssueType] {
        try await client.value(GitHubRequest(.get, "/orgs/\(escape(org))/issue-types"))
    }

    /// Adds an issue type to an organization. `POST /orgs/{org}/issue-types`
    @discardableResult
    public func createType(_ type: IssueTypeInput, in org: String) async throws(GitHubError) -> IssueType {
        try await client.value(GitHubRequest(.post, "/orgs/\(escape(org))/issue-types", body: type))
    }

    /// Replaces an issue type's settings. `PUT /orgs/{org}/issue-types/{issue_type_id}`
    @discardableResult
    public func updateType(id: Int, in org: String, _ type: IssueTypeInput) async throws(GitHubError) -> IssueType {
        try await client.value(GitHubRequest(.put, "/orgs/\(escape(org))/issue-types/\(id)", body: type))
    }

    /// Deletes an issue type. Issues of that type lose it. `DELETE /orgs/{org}/issue-types/{issue_type_id}`
    public func deleteType(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/orgs/\(escape(org))/issue-types/\(id)"))
    }

    // MARK: Issue fields

    /// An organization's custom issue fields. `GET /orgs/{org}/issue-fields`
    public func fields(in org: String) async throws(GitHubError) -> [IssueField] {
        try await client.value(GitHubRequest(.get, "/orgs/\(escape(org))/issue-fields"))
    }

    /// Adds a custom issue field to an organization. `POST /orgs/{org}/issue-fields`
    @discardableResult
    public func createField(_ field: NewIssueField, in org: String) async throws(GitHubError) -> IssueField {
        try await client.value(GitHubRequest(.post, "/orgs/\(escape(org))/issue-fields", body: field))
    }

    /// Changes an issue field. `PATCH /orgs/{org}/issue-fields/{issue_field_id}`
    @discardableResult
    public func updateField(id: Int, in org: String, _ changes: IssueFieldUpdate) async throws(GitHubError) -> IssueField {
        try await client.value(GitHubRequest(.patch, "/orgs/\(escape(org))/issue-fields/\(id)", body: changes))
    }

    /// Deletes an issue field and its values on every issue. `DELETE /orgs/{org}/issue-fields/{issue_field_id}`
    public func deleteField(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/orgs/\(escape(org))/issue-fields/\(id)"))
    }
}
