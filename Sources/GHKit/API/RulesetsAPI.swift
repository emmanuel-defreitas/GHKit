import Foundation

extension GitHubClient {
    /// Rulesets for an organization or a repository.
    ///
    ///     let rulesets = github.rulesets(.repository("octocat", "hello-world"))
    ///     let all = try await rulesets.list().collect()
    public func rulesets(_ owner: RulesetOwner) -> RulesetsAPI {
        RulesetsAPI(client: self, owner: owner)
    }
}

/// Who owns a set of rulesets.
public enum RulesetOwner: Sendable, Hashable {
    case organization(String)
    case repository(String, String)

    /// `/orgs/{org}` or `/repos/{owner}/{repo}`
    var pathPrefix: String {
        switch self {
        case .organization(let login): "/orgs/\(escape(login))"
        case .repository(let owner, let name): "/repos/\(escape(owner))/\(escape(name))"
        }
    }

    var isRepository: Bool {
        if case .repository = self { true } else { false }
    }
}

/// Rulesets, their history, and rule insights for one owner. Reach them with `github.rulesets(_:)`.
///
/// Organization rulesets need an organization owner and GitHub Team or Enterprise.
public struct RulesetsAPI: Sendable {
    let client: GitHubClient
    public let owner: RulesetOwner

    private func path(_ rest: String = "") -> String { "\(owner.pathPrefix)/rulesets\(rest)" }

    // MARK: Rulesets

    /// The owner's rulesets, without their rules.
    ///
    /// `GET /orgs/{org}/rulesets`, `GET /repos/{owner}/{repo}/rulesets`
    /// - Parameters:
    ///   - targets: Only rulesets for these targets. Empty means all.
    ///   - includesParents: For repositories, also returns rulesets from the organization.
    public func list(targets: [RulesetTarget] = [], includesParents: Bool = true, perPage: Int = 100) -> Paginated<Ruleset> {
        let targets = targets.isEmpty ? nil : targets.map(\.rawValue).joined(separator: ",")
        let parents = owner.isRepository ? includesParents : nil
        return client.paginate(
            GitHubRequest(.get, path(), query: .query(("targets", targets), ("includes_parents", parents), ("per_page", perPage))))
    }

    /// One ruleset with its rules.
    ///
    /// `GET /orgs/{org}/rulesets/{ruleset_id}`, `GET /repos/{owner}/{repo}/rulesets/{ruleset_id}`
    /// - Parameter includesParents: For repositories, also finds rulesets from the organization.
    public func ruleset(id: Int, includesParents: Bool = true) async throws(GitHubError) -> Ruleset {
        let parents = owner.isRepository ? includesParents : nil
        return try await client.value(GitHubRequest(.get, path("/\(id)"), query: .query(("includes_parents", parents))))
    }

    /// Creates a ruleset. `POST /orgs/{org}/rulesets`, `POST /repos/{owner}/{repo}/rulesets`
    @discardableResult
    public func create(_ ruleset: NewRuleset) async throws(GitHubError) -> Ruleset {
        try await client.value(GitHubRequest(.post, path(), body: ruleset))
    }

    /// Changes a ruleset. `PUT /orgs/{org}/rulesets/{ruleset_id}`, `PUT /repos/{owner}/{repo}/rulesets/{ruleset_id}`
    @discardableResult
    public func update(id: Int, _ changes: RulesetUpdate) async throws(GitHubError) -> Ruleset {
        try await client.value(GitHubRequest(.put, path("/\(id)"), body: changes))
    }

    /// Deletes a ruleset. `DELETE /orgs/{org}/rulesets/{ruleset_id}`, `DELETE /repos/{owner}/{repo}/rulesets/{ruleset_id}`
    public func delete(id: Int) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path("/\(id)")))
    }

    // MARK: History

    /// Earlier versions of a ruleset, newest first.
    ///
    /// `GET /orgs/{org}/rulesets/{ruleset_id}/history`, `GET /repos/{owner}/{repo}/rulesets/{ruleset_id}/history`
    public func history(of id: Int, perPage: Int = 100) -> Paginated<RulesetVersion> {
        client.paginate(GitHubRequest(.get, path("/\(id)/history"), query: .query(("per_page", perPage))))
    }

    /// One earlier version of a ruleset, with its full ``RulesetVersion/state``.
    ///
    /// `GET /orgs/{org}/rulesets/{ruleset_id}/history/{version_id}`,
    /// `GET /repos/{owner}/{repo}/rulesets/{ruleset_id}/history/{version_id}`
    public func version(_ versionID: Int, of id: Int) async throws(GitHubError) -> RulesetVersion {
        try await client.value(GitHubRequest(.get, path("/\(id)/history/\(versionID)")))
    }

    // MARK: Rule insights

    /// Pushes and how the rules judged them, newest first.
    ///
    /// `GET /orgs/{org}/rulesets/rule-suites`, `GET /repos/{owner}/{repo}/rulesets/rule-suites`
    /// - Parameters:
    ///   - ref: Only pushes to this ref, such as `refs/heads/main`.
    ///   - repository: For organizations, only pushes to this repository.
    ///   - actor: Only pushes by this login.
    public func ruleSuites(
        ref: String? = nil, repository: String? = nil, period: RuleSuitePeriod = .day, actor: String? = nil,
        result: RuleSuiteResultFilter = .all, evaluateStatus: RuleSuiteEvaluateStatus = .all, perPage: Int = 100
    ) -> Paginated<RuleSuite> {
        client.paginate(
            GitHubRequest(
                .get, path("/rule-suites"),
                query: .query(
                    ("ref", ref), ("repository_name", owner.isRepository ? nil : repository), ("time_period", period),
                    ("actor_name", actor), ("rule_suite_result", result), ("evaluate_status", evaluateStatus),
                    ("per_page", perPage))))
    }

    /// One push and every rule evaluated on it.
    ///
    /// `GET /orgs/{org}/rulesets/rule-suites/{rule_suite_id}`, `GET /repos/{owner}/{repo}/rulesets/rule-suites/{rule_suite_id}`
    /// - Parameter includeMetadata: Adds pull request and status check details to each evaluation.
    public func ruleSuite(id: Int, includeMetadata: Bool = false) async throws(GitHubError) -> RuleSuite {
        try await client.value(
            GitHubRequest(.get, path("/rule-suites/\(id)"), query: .query(("include_metadata", includeMetadata ? true : nil))))
    }
}

extension RepositoriesAPI {
    /// Every active rule that applies to a branch, whatever ruleset it comes from.
    /// `GET /repos/{owner}/{repo}/rules/branches/{branch}`
    public func rules(for branch: String, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<AppliedRule> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/rules/branches/\(escapePath(branch))"), query: .query(("per_page", perPage))))
    }
}
