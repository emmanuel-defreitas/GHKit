import Foundation
import GHKitCore

// Deployments, deployment statuses, and environments.
extension RepositoriesAPI {
    // MARK: Deployments

    /// A repository's deployments, newest first. `GET /repos/{owner}/{repo}/deployments`
    public func deployments(
        _ owner: String, _ name: String, sha: String? = nil, ref: String? = nil, task: String? = nil, environment: String? = nil,
        perPage: Int = 100
    ) -> Paginated<Deployment> {
        client.paginate(
            GitHubRequest(
                .get, path(owner, name, "/deployments"),
                query: .query(("sha", sha), ("ref", ref), ("task", task), ("environment", environment), ("per_page", perPage))))
    }

    /// One deployment. `GET /repos/{owner}/{repo}/deployments/{deployment_id}`
    public func deployment(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> Deployment {
        try await client.value(GitHubRequest(.get, path(owner, name, "/deployments/\(id)")))
    }

    /// Creates a deployment. `POST /repos/{owner}/{repo}/deployments`
    /// - Returns: The deployment, or `nil` when GitHub merged the default branch into the ref instead (status 202).
    ///   Create the deployment again once the merge is done.
    /// - Throws: ``GitHubError`` with status 409 when required status checks haven't passed or the merge conflicts.
    @discardableResult
    public func createDeployment(_ deployment: NewDeployment, in owner: String, _ name: String) async throws(GitHubError) -> Deployment? {
        try await client.value(
            GitHubRequest(method: .post, target: .path(path(owner, name, "/deployments")), body: .json(deployment)) { data in
                let decoder = GitHubJSON.decoder()
                guard case .object(let fields) = try decoder.decode(JSONValue.self, from: data), fields["id"] != nil else { return nil }
                return try decoder.decode(Deployment.self, from: data)
            })
    }

    /// Deletes an inactive deployment. Mark it `inactive` with a status first.
    /// `DELETE /repos/{owner}/{repo}/deployments/{deployment_id}`
    public func deleteDeployment(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/deployments/\(id)")))
    }

    // MARK: Deployment statuses

    /// A deployment's progress updates, newest first. `GET /repos/{owner}/{repo}/deployments/{deployment_id}/statuses`
    public func deploymentStatuses(of deploymentID: Int, in owner: String, _ name: String, perPage: Int = 100) -> Paginated<DeploymentStatus> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/deployments/\(deploymentID)/statuses"), query: .query(("per_page", perPage))))
    }

    /// One progress update. `GET /repos/{owner}/{repo}/deployments/{deployment_id}/statuses/{status_id}`
    public func deploymentStatus(
        id: Int, of deploymentID: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentStatus {
        try await client.value(GitHubRequest(.get, path(owner, name, "/deployments/\(deploymentID)/statuses/\(id)")))
    }

    /// Reports a deployment's progress. `POST /repos/{owner}/{repo}/deployments/{deployment_id}/statuses`
    @discardableResult
    public func createDeploymentStatus(
        _ status: NewDeploymentStatus, on deploymentID: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentStatus {
        try await client.value(GitHubRequest(.post, path(owner, name, "/deployments/\(deploymentID)/statuses"), body: status))
    }

    // MARK: Environments

    /// A repository's environments. `GET /repos/{owner}/{repo}/environments`
    public func environments(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<DeploymentEnvironment> {
        client.paginate(.wrappedList(path(owner, name, "/environments"), key: "environments", query: .query(("per_page", perPage))))
    }

    /// One environment. `GET /repos/{owner}/{repo}/environments/{environment_name}`
    public func environment(_ environment: String, in owner: String, _ name: String) async throws(GitHubError) -> DeploymentEnvironment {
        try await client.value(GitHubRequest(.get, environmentPath(owner, name, environment)))
    }

    /// Creates an environment, or changes its protection settings. `PUT /repos/{owner}/{repo}/environments/{environment_name}`
    @discardableResult
    public func setEnvironment(
        _ environment: String, in owner: String, _ name: String, _ settings: EnvironmentSettings = EnvironmentSettings()
    ) async throws(GitHubError) -> DeploymentEnvironment {
        try await client.value(GitHubRequest(.put, environmentPath(owner, name, environment), body: settings))
    }

    /// Deletes an environment. `DELETE /repos/{owner}/{repo}/environments/{environment_name}`
    public func deleteEnvironment(_ environment: String, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, environmentPath(owner, name, environment)))
    }

    func environmentPath(_ owner: String, _ name: String, _ environment: String, _ rest: String = "") -> String {
        path(owner, name, "/environments/\(escape(environment))\(rest)")
    }

    // MARK: Deployment branch patterns

    /// The patterns that refs must match to deploy, when the environment uses ``DeploymentBranchPolicy/customPatterns``.
    /// `GET /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies`
    public func deploymentBranchPatterns(
        for environment: String, in owner: String, _ name: String, perPage: Int = 100
    ) -> Paginated<DeploymentBranchPattern> {
        client.paginate(
            .wrappedList(
                environmentPath(owner, name, environment, "/deployment-branch-policies"), key: "branch_policies",
                query: .query(("per_page", perPage))))
    }

    /// One pattern. `GET /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}`
    public func deploymentBranchPattern(
        id: Int, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentBranchPattern {
        try await client.value(GitHubRequest(.get, environmentPath(owner, name, environment, "/deployment-branch-policies/\(id)")))
    }

    /// Lets matching branches or tags deploy. `POST /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies`
    /// - Parameter pattern: Such as `release/*`. Wildcards don't match `/`.
    @discardableResult
    public func addDeploymentBranchPattern(
        _ pattern: String, type: DeploymentRefType = .branch, to environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentBranchPattern {
        struct Body: Encodable, Sendable {
            let name: String
            let type: DeploymentRefType
        }
        return try await client.value(
            GitHubRequest(
                .post, environmentPath(owner, name, environment, "/deployment-branch-policies"), body: Body(name: pattern, type: type)))
    }

    /// Changes a pattern. `PUT /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}`
    @discardableResult
    public func updateDeploymentBranchPattern(
        id: Int, to pattern: String, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentBranchPattern {
        try await client.value(
            GitHubRequest(.put, environmentPath(owner, name, environment, "/deployment-branch-policies/\(id)"), body: ["name": pattern]))
    }

    /// Removes a pattern. `DELETE /repos/{owner}/{repo}/environments/{environment_name}/deployment-branch-policies/{branch_policy_id}`
    public func deleteDeploymentBranchPattern(
        id: Int, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, environmentPath(owner, name, environment, "/deployment-branch-policies/\(id)")))
    }

    // MARK: Deployment protection rules

    /// The apps that approve or reject deployments to an environment.
    /// `GET /repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules`
    public func deploymentProtectionRules(
        for environment: String, in owner: String, _ name: String
    ) -> Paginated<DeploymentProtectionRule> {
        client.paginate(
            .wrappedList(
                environmentPath(owner, name, environment, "/deployment_protection_rules"), key: "custom_deployment_protection_rules"))
    }

    /// One protection rule.
    /// `GET /repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/{protection_rule_id}`
    public func deploymentProtectionRule(
        id: Int, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentProtectionRule {
        try await client.value(GitHubRequest(.get, environmentPath(owner, name, environment, "/deployment_protection_rules/\(id)")))
    }

    /// Apps installed on the repository that can become protection rules.
    /// `GET /repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/apps`
    public func availableProtectionRuleApps(
        for environment: String, in owner: String, _ name: String, perPage: Int = 100
    ) -> Paginated<ProtectionRuleApp> {
        client.paginate(
            .wrappedList(
                environmentPath(owner, name, environment, "/deployment_protection_rules/apps"),
                key: "available_custom_deployment_protection_rule_integrations", query: .query(("per_page", perPage))))
    }

    /// Makes an app approve or reject deployments to an environment.
    /// `POST /repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules`
    @discardableResult
    public func enableProtectionRule(
        appID: Int, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) -> DeploymentProtectionRule {
        try await client.value(
            GitHubRequest(.post, environmentPath(owner, name, environment, "/deployment_protection_rules"), body: ["integration_id": appID]))
    }

    /// Stops an app gating deployments to an environment.
    /// `DELETE /repos/{owner}/{repo}/environments/{environment_name}/deployment_protection_rules/{protection_rule_id}`
    public func disableProtectionRule(
        id: Int, for environment: String, in owner: String, _ name: String
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(.delete, environmentPath(owner, name, environment, "/deployment_protection_rules/\(id)")))
    }
}
