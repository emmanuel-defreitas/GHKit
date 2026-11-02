import Foundation

// Branches, merges, and branch protection.
extension RepositoriesAPI {
    func branchPath(_ owner: String, _ name: String, _ branch: String, _ rest: String = "") -> String {
        // Branch names keep their slashes, as in `/branches/release/v1/protection`.
        path(owner, name, "/branches/\(escapePath(branch))\(rest)")
    }

    func protectionPath(_ owner: String, _ name: String, _ branch: String, _ rest: String = "") -> String {
        branchPath(owner, name, branch, "/protection\(rest)")
    }

    // MARK: Branches

    /// A repository's branches. `GET /repos/{owner}/{repo}/branches`
    /// - Parameter protected: Only protected branches when `true`, only unprotected ones when `false`.
    public func branches(_ owner: String, _ name: String, protected: Bool? = nil, perPage: Int = 100) -> Paginated<Branch> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/branches"), query: .query(("protected", protected), ("per_page", perPage))))
    }

    /// One branch, with its head commit and protection. `GET /repos/{owner}/{repo}/branches/{branch}`
    public func branch(_ branch: String, in owner: String, _ name: String) async throws(GitHubError) -> BranchDetails {
        try await client.value(GitHubRequest(.get, branchPath(owner, name, branch)))
    }

    /// Renames a branch and retargets its pull requests. `POST /repos/{owner}/{repo}/branches/{branch}/rename`
    @discardableResult
    public func renameBranch(
        _ branch: String, to newName: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> BranchDetails {
        try await client.value(GitHubRequest(.post, branchPath(owner, name, branch, "/rename"), body: ["new_name": newName]))
    }

    /// The branches whose head is a commit. `GET /repos/{owner}/{repo}/commits/{commit_sha}/branches-where-head`
    public func branches(withHead sha: String, in owner: String, _ name: String) async throws(GitHubError) -> [Branch] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/commits/\(escape(sha))/branches-where-head")))
    }

    /// Merges a branch or commit into another branch. `POST /repos/{owner}/{repo}/merges`
    /// - Parameter head: A branch name or commit SHA.
    /// - Returns: The merge commit, or `nil` when `base` already contains `head`.
    /// - Throws: ``GitHubError`` with status 409 when the merge has conflicts.
    @discardableResult
    public func merge(
        _ head: String, into base: String, in owner: String, _ name: String, message: String? = nil
    ) async throws(GitHubError) -> Commit? {
        struct Body: Encodable, Sendable {
            let base: String
            let head: String
            let commitMessage: String?
            enum CodingKeys: String, CodingKey {
                case base, head
                case commitMessage = "commit_message"
            }
        }
        let body = Body(base: base, head: head, commitMessage: message)
        return try await client.value(
            GitHubRequest(method: .post, target: .path(path(owner, name, "/merges")), body: .json(body)) { data in
                data.isEmpty ? nil : try GitHubJSON.decoder().decode(Commit.self, from: data)
            })
    }

    // MARK: Protection

    /// A branch's protection rules. `GET /repos/{owner}/{repo}/branches/{branch}/protection`
    public func protection(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> BranchProtection {
        try await client.value(GitHubRequest(.get, protectionPath(owner, name, branch)))
    }

    /// Replaces every protection rule on a branch. `PUT /repos/{owner}/{repo}/branches/{branch}/protection`
    @discardableResult
    public func protect(
        _ branch: String, in owner: String, _ name: String, rules: BranchProtectionRules
    ) async throws(GitHubError) -> BranchProtection {
        try await client.value(GitHubRequest(.put, protectionPath(owner, name, branch), body: rules))
    }

    /// Removes all protection from a branch. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection`
    public func removeProtection(from branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, protectionPath(owner, name, branch)))
    }

    /// Whether the rules also bind administrators. `GET /repos/{owner}/{repo}/branches/{branch}/protection/enforce_admins`
    public func adminEnforcement(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await flag(protectionPath(owner, name, branch, "/enforce_admins"))
    }

    /// Makes the rules bind administrators too, or stops them doing so.
    /// `POST` or `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/enforce_admins`
    public func setAdminEnforcement(_ enabled: Bool, on branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(enabled ? .post : .delete, protectionPath(owner, name, branch, "/enforce_admins")))
    }

    /// Whether commits must be signed. `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_signatures`
    public func signatureRequirement(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await flag(protectionPath(owner, name, branch, "/required_signatures"))
    }

    /// Requires signed commits, or stops requiring them.
    /// `POST` or `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/required_signatures`
    public func setSignatureRequirement(_ enabled: Bool, on branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(enabled ? .post : .delete, protectionPath(owner, name, branch, "/required_signatures")))
    }

    private func flag(_ path: String) async throws(GitHubError) -> Bool {
        struct Flag: Decodable, Sendable { let enabled: Bool }
        let flag: Flag = try await client.value(GitHubRequest(.get, path))
        return flag.enabled
    }

    // MARK: Review protection

    /// A branch's pull request review rules.
    /// `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews`
    public func reviewProtection(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> ReviewProtection {
        try await client.value(GitHubRequest(.get, protectionPath(owner, name, branch, "/required_pull_request_reviews")))
    }

    /// Changes a branch's review rules. Rules you leave `nil` keep their current value.
    /// `PATCH /repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews`
    @discardableResult
    public func updateReviewProtection(
        _ reviews: RequiredReviews, on branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> ReviewProtection {
        try await client.value(
            GitHubRequest(.patch, protectionPath(owner, name, branch, "/required_pull_request_reviews"), body: reviews))
    }

    /// Stops requiring pull request reviews.
    /// `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/required_pull_request_reviews`
    public func removeReviewProtection(from branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, protectionPath(owner, name, branch, "/required_pull_request_reviews")))
    }

    // MARK: Status checks

    /// The status checks a branch requires. `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks`
    public func statusChecks(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> StatusCheckPolicy {
        try await client.value(GitHubRequest(.get, protectionPath(owner, name, branch, "/required_status_checks")))
    }

    /// Changes a branch's required status checks. Values you leave `nil` keep their current value.
    /// `PATCH /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks`
    @discardableResult
    public func updateStatusChecks(
        on branch: String, in owner: String, _ name: String, strict: Bool? = nil, checks: [StatusCheck]? = nil
    ) async throws(GitHubError) -> StatusCheckPolicy {
        struct Body: Encodable, Sendable {
            let strict: Bool?
            let checks: [StatusCheck]?
        }
        return try await client.value(
            GitHubRequest(
                .patch, protectionPath(owner, name, branch, "/required_status_checks"), body: Body(strict: strict, checks: checks)))
    }

    /// Stops requiring status checks. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks`
    public func removeStatusChecks(from branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, protectionPath(owner, name, branch, "/required_status_checks")))
    }

    /// The names of the required checks.
    /// `GET /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts`
    public func statusCheckContexts(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [String] {
        try await client.value(GitHubRequest(.get, contextsPath(owner, name, branch)))
    }

    /// Adds required checks by name.
    /// `POST /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts`
    @discardableResult
    public func addStatusCheckContexts(
        _ contexts: [String], to branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [String] {
        try await client.value(GitHubRequest(.post, contextsPath(owner, name, branch), body: ["contexts": contexts]))
    }

    /// Replaces the required checks.
    /// `PUT /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts`
    @discardableResult
    public func setStatusCheckContexts(
        _ contexts: [String], on branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [String] {
        try await client.value(GitHubRequest(.put, contextsPath(owner, name, branch), body: ["contexts": contexts]))
    }

    /// Removes required checks by name.
    /// `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/required_status_checks/contexts`
    @discardableResult
    public func removeStatusCheckContexts(
        _ contexts: [String], from branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [String] {
        try await client.value(GitHubRequest(.delete, contextsPath(owner, name, branch), body: ["contexts": contexts]))
    }

    private func contextsPath(_ owner: String, _ name: String, _ branch: String) -> String {
        protectionPath(owner, name, branch, "/required_status_checks/contexts")
    }

    // MARK: Push restrictions

    /// Who can push to a branch. `GET /repos/{owner}/{repo}/branches/{branch}/protection/restrictions`
    public func pushRestrictions(of branch: String, in owner: String, _ name: String) async throws(GitHubError) -> BranchRestrictions {
        try await client.value(GitHubRequest(.get, protectionPath(owner, name, branch, "/restrictions")))
    }

    /// Lets anyone with write access push again. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions`
    public func removePushRestrictions(from branch: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, protectionPath(owner, name, branch, "/restrictions")))
    }

    /// The people who can push. `GET /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users`
    public func usersWithPushAccess(to branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [SimpleUser] {
        try await pushAccess(.get, "users", nil, branch, owner, name)
    }

    /// The teams that can push. `GET /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams`
    public func teamsWithPushAccess(to branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [Team] {
        try await pushAccess(.get, "teams", nil, branch, owner, name)
    }

    /// The GitHub Apps that can push. `GET /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps`
    public func appsWithPushAccess(to branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [GitHubApp] {
        try await pushAccess(.get, "apps", nil, branch, owner, name)
    }

    /// Lets more people push. `POST /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users`
    @discardableResult
    public func addPushAccess(
        users: [String], to branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [SimpleUser] {
        try await pushAccess(.post, "users", users, branch, owner, name)
    }

    /// Lets more teams push, by slug. `POST /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams`
    @discardableResult
    public func addPushAccess(teams: [String], to branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [Team] {
        try await pushAccess(.post, "teams", teams, branch, owner, name)
    }

    /// Lets more GitHub Apps push, by slug. `POST /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps`
    @discardableResult
    public func addPushAccess(
        apps: [String], to branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [GitHubApp] {
        try await pushAccess(.post, "apps", apps, branch, owner, name)
    }

    /// Replaces the people who can push. `PUT /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users`
    @discardableResult
    public func setPushAccess(
        users: [String], on branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [SimpleUser] {
        try await pushAccess(.put, "users", users, branch, owner, name)
    }

    /// Replaces the teams that can push. `PUT /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams`
    @discardableResult
    public func setPushAccess(teams: [String], on branch: String, in owner: String, _ name: String) async throws(GitHubError) -> [Team] {
        try await pushAccess(.put, "teams", teams, branch, owner, name)
    }

    /// Replaces the GitHub Apps that can push. `PUT /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps`
    @discardableResult
    public func setPushAccess(
        apps: [String], on branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [GitHubApp] {
        try await pushAccess(.put, "apps", apps, branch, owner, name)
    }

    /// Stops people pushing. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/users`
    @discardableResult
    public func removePushAccess(
        users: [String], from branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [SimpleUser] {
        try await pushAccess(.delete, "users", users, branch, owner, name)
    }

    /// Stops teams pushing. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/teams`
    @discardableResult
    public func removePushAccess(
        teams: [String], from branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [Team] {
        try await pushAccess(.delete, "teams", teams, branch, owner, name)
    }

    /// Stops GitHub Apps pushing. `DELETE /repos/{owner}/{repo}/branches/{branch}/protection/restrictions/apps`
    @discardableResult
    public func removePushAccess(
        apps: [String], from branch: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> [GitHubApp] {
        try await pushAccess(.delete, "apps", apps, branch, owner, name)
    }

    private func pushAccess<Value: Decodable & Sendable>(
        _ method: HTTPMethod, _ kind: String, _ values: [String]?, _ branch: String, _ owner: String, _ name: String
    ) async throws(GitHubError) -> [Value] {
        try await client.value(
            GitHubRequest(method, protectionPath(owner, name, branch, "/restrictions/\(kind)"), body: values.map { [kind: $0] }))
    }
}
