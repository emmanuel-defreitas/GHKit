import Foundation

// Security settings, custom property values, and repository dispatch events.
extension RepositoriesAPI {
    // MARK: Security settings

    /// Whether Dependabot alerts are on. Needs admin access. `GET /repos/{owner}/{repo}/vulnerability-alerts`
    public func vulnerabilityAlertsEnabled(_ owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists(path(owner, name, "/vulnerability-alerts"))
    }

    /// Turns Dependabot alerts on or off.
    /// `PUT /repos/{owner}/{repo}/vulnerability-alerts`, `DELETE /repos/{owner}/{repo}/vulnerability-alerts`
    public func setVulnerabilityAlerts(enabled: Bool, in owner: String, _ name: String) async throws(GitHubError) {
        try await toggle(enabled, path(owner, name, "/vulnerability-alerts"))
    }

    /// Whether Dependabot security updates are on, and whether they're paused.
    /// `GET /repos/{owner}/{repo}/automated-security-fixes`
    /// - Throws: ``GitHubError`` with status 404 when Dependabot alerts are off.
    public func dependabotSecurityUpdates(_ owner: String, _ name: String) async throws(GitHubError) -> DependabotSecurityUpdatesStatus {
        try await client.value(GitHubRequest(.get, path(owner, name, "/automated-security-fixes")))
    }

    /// Turns Dependabot security updates on or off. They need Dependabot alerts.
    /// `PUT /repos/{owner}/{repo}/automated-security-fixes`, `DELETE /repos/{owner}/{repo}/automated-security-fixes`
    public func setDependabotSecurityUpdates(enabled: Bool, in owner: String, _ name: String) async throws(GitHubError) {
        try await toggle(enabled, path(owner, name, "/automated-security-fixes"))
    }

    /// Whether people can report vulnerabilities to the maintainers privately.
    /// `GET /repos/{owner}/{repo}/private-vulnerability-reporting`
    public func privateVulnerabilityReportingEnabled(_ owner: String, _ name: String) async throws(GitHubError) -> Bool {
        struct Response: Decodable, Sendable { let enabled: Bool }
        return try await client.value(GitHubRequest<Response>(.get, path(owner, name, "/private-vulnerability-reporting"))).enabled
    }

    /// Turns private vulnerability reporting on or off.
    /// `PUT /repos/{owner}/{repo}/private-vulnerability-reporting`, `DELETE /repos/{owner}/{repo}/private-vulnerability-reporting`
    public func setPrivateVulnerabilityReporting(enabled: Bool, in owner: String, _ name: String) async throws(GitHubError) {
        try await toggle(enabled, path(owner, name, "/private-vulnerability-reporting"))
    }

    /// Whether new releases are locked once published. `GET /repos/{owner}/{repo}/immutable-releases`
    /// - Throws: ``GitHubError`` with status 404 when immutable releases are off.
    public func immutableReleases(_ owner: String, _ name: String) async throws(GitHubError) -> ImmutableReleasesStatus {
        try await client.value(GitHubRequest(.get, path(owner, name, "/immutable-releases")))
    }

    /// Turns immutable releases on or off. Fails with 409 when the owner enforces the setting.
    /// `PUT /repos/{owner}/{repo}/immutable-releases`, `DELETE /repos/{owner}/{repo}/immutable-releases`
    public func setImmutableReleases(enabled: Bool, in owner: String, _ name: String) async throws(GitHubError) {
        try await toggle(enabled, path(owner, name, "/immutable-releases"))
    }

    private func toggle(_ enabled: Bool, _ path: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(enabled ? .put : .delete, path))
    }

    // MARK: Custom properties

    /// The organization's custom property values on this repository. `GET /repos/{owner}/{repo}/properties/values`
    public func customPropertyValues(_ owner: String, _ name: String) async throws(GitHubError) -> [CustomPropertyValue] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/properties/values")))
    }

    /// Sets custom property values. A `nil` value removes it. `PATCH /repos/{owner}/{repo}/properties/values`
    public func setCustomPropertyValues(_ values: [CustomPropertyValue], in owner: String, _ name: String) async throws(GitHubError) {
        struct Body: Encodable, Sendable { let properties: [CustomPropertyValue] }
        try await client.value(GitHubRequest<Void>(.patch, path(owner, name, "/properties/values"), body: Body(properties: values)))
    }

    // MARK: Dispatch

    /// Triggers workflows that listen for `repository_dispatch`, and a webhook event of the same name.
    /// `POST /repos/{owner}/{repo}/dispatches`
    /// - Parameters:
    ///   - eventType: A name of up to 100 characters, matched by the workflow's `types` filter.
    ///   - payload: Up to 10 top-level keys, under 64 KB. Workflows read it as `github.event.client_payload`.
    public func dispatch(
        _ eventType: String, payload: [String: JSONValue]? = nil, to owner: String, _ name: String
    ) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let eventType: String
            let clientPayload: [String: JSONValue]?

            enum CodingKeys: String, CodingKey {
                case eventType = "event_type"
                case clientPayload = "client_payload"
            }
        }
        try await client.value(
            GitHubRequest<Void>(.post, path(owner, name, "/dispatches"), body: Body(eventType: eventType, clientPayload: payload)))
    }
}
