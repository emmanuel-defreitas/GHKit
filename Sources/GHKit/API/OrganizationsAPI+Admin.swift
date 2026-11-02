import Foundation

// Organization administration: webhooks, fine-grained roles, and fine-grained token approvals.
// Most of these need an organization owner, or a GitHub App with organization administration permission.
extension OrganizationsAPI {
    // MARK: Webhooks

    /// An organization's webhooks. `GET /orgs/{org}/hooks`
    public func webhooks(of org: String, perPage: Int = 100) -> Paginated<OrganizationWebhook> {
        client.paginate(GitHubRequest(.get, path(org, "/hooks"), query: .query(("per_page", perPage))))
    }

    /// One webhook. `GET /orgs/{org}/hooks/{hook_id}`
    public func webhook(id: Int, in org: String) async throws(GitHubError) -> OrganizationWebhook {
        try await client.value(GitHubRequest(.get, path(org, "/hooks/\(id)")))
    }

    /// Creates a webhook. `POST /orgs/{org}/hooks`
    @discardableResult
    public func createWebhook(_ webhook: NewWebhook, in org: String) async throws(GitHubError) -> OrganizationWebhook {
        try await client.value(GitHubRequest(.post, path(org, "/hooks"), body: webhook))
    }

    /// Changes a webhook's events, status, or configuration. `PATCH /orgs/{org}/hooks/{hook_id}`
    @discardableResult
    public func updateWebhook(id: Int, in org: String, _ changes: WebhookUpdate) async throws(GitHubError) -> OrganizationWebhook {
        try await client.value(GitHubRequest(.patch, path(org, "/hooks/\(id)"), body: changes))
    }

    /// Deletes a webhook. `DELETE /orgs/{org}/hooks/{hook_id}`
    public func deleteWebhook(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/hooks/\(id)")))
    }

    /// A webhook's delivery settings. `GET /orgs/{org}/hooks/{hook_id}/config`
    public func webhookConfiguration(id: Int, in org: String) async throws(GitHubError) -> WebhookConfiguration {
        try await client.value(GitHubRequest(.get, path(org, "/hooks/\(id)/config")))
    }

    /// Changes only a webhook's delivery settings. `PATCH /orgs/{org}/hooks/{hook_id}/config`
    @discardableResult
    public func updateWebhookConfiguration(
        id: Int, in org: String, _ configuration: WebhookConfiguration
    ) async throws(GitHubError) -> WebhookConfiguration {
        try await client.value(GitHubRequest(.patch, path(org, "/hooks/\(id)/config"), body: configuration))
    }

    /// Recent deliveries for a webhook, newest first. `GET /orgs/{org}/hooks/{hook_id}/deliveries`
    public func webhookDeliveries(
        id: Int, in org: String, status: WebhookDeliveryStatus? = nil, perPage: Int = 100
    ) -> Paginated<WebhookDelivery> {
        client.paginate(
            GitHubRequest(.get, path(org, "/hooks/\(id)/deliveries"), query: .query(("status", status), ("per_page", perPage))))
    }

    /// One delivery, with the request and response. `GET /orgs/{org}/hooks/{hook_id}/deliveries/{delivery_id}`
    public func webhookDelivery(_ deliveryID: Int, webhook id: Int, in org: String) async throws(GitHubError) -> WebhookDeliveryDetail {
        try await client.value(GitHubRequest(.get, path(org, "/hooks/\(id)/deliveries/\(deliveryID)")))
    }

    /// Sends a delivery again. `POST /orgs/{org}/hooks/{hook_id}/deliveries/{delivery_id}/attempts`
    public func redeliver(_ deliveryID: Int, webhook id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(org, "/hooks/\(id)/deliveries/\(deliveryID)/attempts")))
    }

    /// Sends a `ping` event to a webhook. `POST /orgs/{org}/hooks/{hook_id}/pings`
    public func pingWebhook(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(org, "/hooks/\(id)/pings")))
    }

    // MARK: Organization roles

    /// Every fine-grained role in the organization, predefined and custom. `GET /orgs/{org}/organization-roles`
    public func roles(of org: String) async throws(GitHubError) -> [OrganizationRoleDefinition] {
        struct Response: Decodable, Sendable { let roles: [OrganizationRoleDefinition] }
        let response: Response = try await client.value(GitHubRequest(.get, path(org, "/organization-roles")))
        return response.roles
    }

    /// One fine-grained role. `GET /orgs/{org}/organization-roles/{role_id}`
    public func role(id: Int, in org: String) async throws(GitHubError) -> OrganizationRoleDefinition {
        try await client.value(GitHubRequest(.get, path(org, "/organization-roles/\(id)")))
    }

    /// Teams that hold a role. `GET /orgs/{org}/organization-roles/{role_id}/teams`
    public func teams(withRole id: Int, in org: String, perPage: Int = 100) -> Paginated<TeamRoleAssignment> {
        client.paginate(GitHubRequest(.get, path(org, "/organization-roles/\(id)/teams"), query: .query(("per_page", perPage))))
    }

    /// Users who hold a role, directly or through a team. `GET /orgs/{org}/organization-roles/{role_id}/users`
    public func users(withRole id: Int, in org: String, perPage: Int = 100) -> Paginated<UserRoleAssignment> {
        client.paginate(GitHubRequest(.get, path(org, "/organization-roles/\(id)/users"), query: .query(("per_page", perPage))))
    }

    /// Gives a team a role. `PUT /orgs/{org}/organization-roles/teams/{team_slug}/{role_id}`
    public func assignRole(_ id: Int, toTeam slug: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/organization-roles/teams/\(escape(slug))/\(id)")))
    }

    /// Takes a role from a team. `DELETE /orgs/{org}/organization-roles/teams/{team_slug}/{role_id}`
    public func revokeRole(_ id: Int, fromTeam slug: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/organization-roles/teams/\(escape(slug))/\(id)")))
    }

    /// Takes every role from a team. `DELETE /orgs/{org}/organization-roles/teams/{team_slug}`
    public func revokeAllRoles(fromTeam slug: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/organization-roles/teams/\(escape(slug))")))
    }

    /// Gives a user a role. `PUT /orgs/{org}/organization-roles/users/{username}/{role_id}`
    public func assignRole(_ id: Int, toUser login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/organization-roles/users/\(escape(login))/\(id)")))
    }

    /// Takes a role from a user. `DELETE /orgs/{org}/organization-roles/users/{username}/{role_id}`
    public func revokeRole(_ id: Int, fromUser login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/organization-roles/users/\(escape(login))/\(id)")))
    }

    /// Takes every directly assigned role from a user. `DELETE /orgs/{org}/organization-roles/users/{username}`
    public func revokeAllRoles(fromUser login: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/organization-roles/users/\(escape(login))")))
    }

    // MARK: Fine-grained personal access tokens

    /// Fine-grained tokens waiting for approval. `GET /orgs/{org}/personal-access-token-requests`
    public func tokenRequests(
        in org: String, matching filter: TokenFilter = TokenFilter(), perPage: Int = 100
    ) -> Paginated<PersonalAccessTokenRequest> {
        client.paginate(GitHubRequest(.get, path(org, "/personal-access-token-requests"), query: filter.query(perPage: perPage)))
    }

    /// Repositories a token request asks for. `GET /orgs/{org}/personal-access-token-requests/{pat_request_id}/repositories`
    public func tokenRequestRepositories(id: Int, in org: String, perPage: Int = 100) -> Paginated<Repository> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/personal-access-token-requests/\(id)/repositories"), query: .query(("per_page", perPage))))
    }

    /// Approves or denies one token request. `POST /orgs/{org}/personal-access-token-requests/{pat_request_id}`
    public func reviewTokenRequest(
        id: Int, in org: String, _ decision: TokenRequestDecision, reason: String? = nil
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(
                .post, path(org, "/personal-access-token-requests/\(id)"), body: TokenReview(action: decision, reason: reason)))
    }

    /// Approves or denies several token requests at once. `POST /orgs/{org}/personal-access-token-requests`
    /// - Parameter ids: The requests to review. `nil` reviews every pending request.
    public func reviewTokenRequests(
        ids: [Int]?, in org: String, _ decision: TokenRequestDecision, reason: String? = nil
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(
                .post, path(org, "/personal-access-token-requests"),
                body: TokenReview(patRequestIDs: ids, action: decision, reason: reason)))
    }

    /// Fine-grained tokens with access to the organization. `GET /orgs/{org}/personal-access-tokens`
    public func tokenGrants(
        in org: String, matching filter: TokenFilter = TokenFilter(), perPage: Int = 100
    ) -> Paginated<PersonalAccessTokenGrant> {
        client.paginate(GitHubRequest(.get, path(org, "/personal-access-tokens"), query: filter.query(perPage: perPage)))
    }

    /// Repositories a token can reach. `GET /orgs/{org}/personal-access-tokens/{pat_id}/repositories`
    public func tokenGrantRepositories(id: Int, in org: String, perPage: Int = 100) -> Paginated<Repository> {
        client.paginate(
            GitHubRequest(.get, path(org, "/personal-access-tokens/\(id)/repositories"), query: .query(("per_page", perPage))))
    }

    /// Revokes one token's access to the organization. `POST /orgs/{org}/personal-access-tokens/{pat_id}`
    public func revokeTokenGrant(id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(org, "/personal-access-tokens/\(id)"), body: TokenRevoke()))
    }

    /// Revokes several tokens' access to the organization. `POST /orgs/{org}/personal-access-tokens`
    public func revokeTokenGrants(ids: [Int], in org: String) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(.post, path(org, "/personal-access-tokens"), body: TokenRevoke(patIDs: ids)))
    }
}

private struct TokenReview: Encodable, Sendable {
    var patRequestIDs: [Int]? = nil
    let action: TokenRequestDecision
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case action, reason
        case patRequestIDs = "pat_request_ids"
    }
}

private struct TokenRevoke: Encodable, Sendable {
    let action = "revoke"
    var patIDs: [Int]? = nil

    enum CodingKeys: String, CodingKey {
        case action
        case patIDs = "pat_ids"
    }
}
