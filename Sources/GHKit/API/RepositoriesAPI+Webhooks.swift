import Foundation

// Repository webhooks and their deliveries. These need admin access to the repository.
extension RepositoriesAPI {
    /// A repository's webhooks. `GET /repos/{owner}/{repo}/hooks`
    public func webhooks(_ owner: String, _ name: String, perPage: Int = 100) -> Paginated<RepositoryWebhook> {
        client.paginate(GitHubRequest(.get, path(owner, name, "/hooks"), query: .query(("per_page", perPage))))
    }

    /// One webhook. `GET /repos/{owner}/{repo}/hooks/{hook_id}`
    public func webhook(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> RepositoryWebhook {
        try await client.value(GitHubRequest(.get, path(owner, name, "/hooks/\(id)")))
    }

    /// Creates a webhook. `POST /repos/{owner}/{repo}/hooks`
    @discardableResult
    public func createWebhook(_ webhook: NewWebhook, in owner: String, _ name: String) async throws(GitHubError) -> RepositoryWebhook {
        try await client.value(GitHubRequest(.post, path(owner, name, "/hooks"), body: webhook))
    }

    /// Changes a webhook's events, status, or configuration. `PATCH /repos/{owner}/{repo}/hooks/{hook_id}`
    @discardableResult
    public func updateWebhook(
        id: Int, in owner: String, _ name: String, _ changes: WebhookUpdate
    ) async throws(GitHubError) -> RepositoryWebhook {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/hooks/\(id)"), body: changes))
    }

    /// Deletes a webhook. `DELETE /repos/{owner}/{repo}/hooks/{hook_id}`
    public func deleteWebhook(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(owner, name, "/hooks/\(id)")))
    }

    /// A webhook's delivery settings. `GET /repos/{owner}/{repo}/hooks/{hook_id}/config`
    public func webhookConfiguration(id: Int, in owner: String, _ name: String) async throws(GitHubError) -> WebhookConfiguration {
        try await client.value(GitHubRequest(.get, path(owner, name, "/hooks/\(id)/config")))
    }

    /// Changes only a webhook's delivery settings. `PATCH /repos/{owner}/{repo}/hooks/{hook_id}/config`
    @discardableResult
    public func updateWebhookConfiguration(
        id: Int, in owner: String, _ name: String, _ configuration: WebhookConfiguration
    ) async throws(GitHubError) -> WebhookConfiguration {
        try await client.value(GitHubRequest(.patch, path(owner, name, "/hooks/\(id)/config"), body: configuration))
    }

    /// Recent deliveries for a webhook, newest first. `GET /repos/{owner}/{repo}/hooks/{hook_id}/deliveries`
    public func webhookDeliveries(
        id: Int, in owner: String, _ name: String, status: WebhookDeliveryStatus? = nil, perPage: Int = 100
    ) -> Paginated<WebhookDelivery> {
        client.paginate(
            GitHubRequest(.get, path(owner, name, "/hooks/\(id)/deliveries"), query: .query(("status", status), ("per_page", perPage))))
    }

    /// One delivery, with the request and response. `GET /repos/{owner}/{repo}/hooks/{hook_id}/deliveries/{delivery_id}`
    public func webhookDelivery(
        _ deliveryID: Int, webhook id: Int, in owner: String, _ name: String
    ) async throws(GitHubError) -> WebhookDeliveryDetail {
        try await client.value(GitHubRequest(.get, path(owner, name, "/hooks/\(id)/deliveries/\(deliveryID)")))
    }

    /// Sends a delivery again. `POST /repos/{owner}/{repo}/hooks/{hook_id}/deliveries/{delivery_id}/attempts`
    public func redeliver(_ deliveryID: Int, webhook id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/hooks/\(id)/deliveries/\(deliveryID)/attempts")))
    }

    /// Sends a `ping` event to a webhook. `POST /repos/{owner}/{repo}/hooks/{hook_id}/pings`
    public func pingWebhook(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/hooks/\(id)/pings")))
    }

    /// Sends the latest push to a webhook subscribed to `push`. Does nothing for other webhooks.
    /// `POST /repos/{owner}/{repo}/hooks/{hook_id}/tests`
    public func testWebhook(id: Int, in owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.post, path(owner, name, "/hooks/\(id)/tests")))
    }
}
