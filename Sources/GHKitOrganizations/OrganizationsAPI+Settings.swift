import Foundation
import GHKitCore

// Organization settings: custom properties, immutable releases, and API insights.
extension OrganizationsAPI {
    // MARK: Custom properties

    /// The organization's custom property definitions. `GET /orgs/{org}/properties/schema`
    public func customProperties(of org: String) async throws(GitHubError) -> [CustomProperty] {
        try await client.value(GitHubRequest(.get, path(org, "/properties/schema")))
    }

    /// One custom property definition. `GET /orgs/{org}/properties/schema/{custom_property_name}`
    public func customProperty(_ name: String, in org: String) async throws(GitHubError) -> CustomProperty {
        try await client.value(GitHubRequest(.get, path(org, "/properties/schema/\(escape(name))")))
    }

    /// Creates or updates several property definitions. `PATCH /orgs/{org}/properties/schema`
    @discardableResult
    public func setCustomProperties(_ properties: [CustomProperty], in org: String) async throws(GitHubError) -> [CustomProperty] {
        struct Body: Encodable, Sendable { let properties: [CustomProperty] }
        return try await client.value(GitHubRequest(.patch, path(org, "/properties/schema"), body: Body(properties: properties)))
    }

    /// Creates or updates one property definition. `PUT /orgs/{org}/properties/schema/{custom_property_name}`
    @discardableResult
    public func setCustomProperty(_ property: CustomProperty, in org: String) async throws(GitHubError) -> CustomProperty {
        try await client.value(
            GitHubRequest(.put, path(org, "/properties/schema/\(escape(property.name))"), body: PropertyDefinitionBody(property)))
    }

    /// Deletes a property definition and its value on every repository. `DELETE /orgs/{org}/properties/schema/{custom_property_name}`
    public func deleteCustomProperty(_ name: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/properties/schema/\(escape(name))")))
    }

    /// Every repository's property values. `GET /orgs/{org}/properties/values`
    /// - Parameter repositoryQuery: Narrows the repositories with search syntax, such as `props.environment:production`.
    public func customPropertyValues(
        in org: String, repositoryQuery: String? = nil, perPage: Int = 100
    ) -> Paginated<RepositoryPropertyValues> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/properties/values"), query: .query(("repository_query", repositoryQuery), ("per_page", perPage))))
    }

    /// Sets property values on up to 30 repositories. `PATCH /orgs/{org}/properties/values`
    public func setCustomPropertyValues(
        _ values: [CustomPropertyValue], onRepositories names: [String], in org: String
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(.patch, path(org, "/properties/values"), body: PropertyValuesBody(repositoryNames: names, properties: values)))
    }

    // MARK: External properties

    /// App installations registered to manage external properties. `GET /orgs/{org}/properties/installations`
    public func externalPropertyInstallations(of org: String) async throws(GitHubError) -> [ExternalPropertyInstallation] {
        try await client.value(GitHubRequest(.get, path(org, "/properties/installations")))
    }

    /// Registers an app installation to manage external properties. `POST /orgs/{org}/properties/installations`
    /// - Parameter installationID: The installation to register. `nil` uses the installation making the call.
    @discardableResult
    public func registerExternalPropertyInstallation(
        _ installationID: Int? = nil, displayName: String, in org: String
    ) async throws(GitHubError) -> ExternalPropertyInstallation {
        struct Body: Encodable, Sendable {
            let installationID: Int?
            let displayName: String
            enum CodingKeys: String, CodingKey {
                case installationID = "installation_id"
                case displayName = "display_name"
            }
        }
        return try await client.value(
            GitHubRequest(
                .post, path(org, "/properties/installations"), body: Body(installationID: installationID, displayName: displayName)))
    }

    /// External property definitions. `GET /orgs/{org}/properties/installations/schema`
    public func externalProperties(of org: String) async throws(GitHubError) -> [ExternalProperty] {
        try await client.value(GitHubRequest(.get, path(org, "/properties/installations/schema")))
    }

    /// Sets external property values on several repositories. `PATCH /orgs/{org}/properties/installations/values`
    public func setExternalPropertyValues(
        _ values: [CustomPropertyValue], onRepositories names: [String], in org: String
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(
                .patch, path(org, "/properties/installations/values"),
                body: PropertyValuesBody(repositoryNames: names, properties: values)))
    }

    /// Sets one external property per repository. `nil` unsets it.
    /// `PATCH /orgs/{org}/properties/installations/values/{property_name}`
    /// - Parameter values: Repository name to value.
    public func setExternalPropertyValue(
        _ name: String, values: [String: String?], in org: String
    ) async throws(GitHubError) {
        try await client.value(
            GitHubRequest<Void>(
                .patch, path(org, "/properties/installations/values/\(escape(name))"), body: ExternalValuesBody(values)))
    }

    /// Removes an external property's value from every repository.
    /// `DELETE /orgs/{org}/properties/installations/values/{property_name}`
    public func deleteExternalPropertyValues(_ name: String, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/properties/installations/values/\(escape(name))")))
    }

    // MARK: Immutable releases

    /// Which repositories must use immutable releases. `GET /orgs/{org}/settings/immutable-releases`
    public func immutableReleasesSettings(of org: String) async throws(GitHubError) -> ImmutableReleasesSettings {
        try await client.value(GitHubRequest(.get, path(org, "/settings/immutable-releases")))
    }

    /// Sets which repositories must use immutable releases. `PUT /orgs/{org}/settings/immutable-releases`
    public func setImmutableReleases(_ policy: ImmutableReleasesPolicy, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/settings/immutable-releases"), body: policy))
    }

    /// The chosen repositories, when the policy is `.selected`. `GET /orgs/{org}/settings/immutable-releases/repositories`
    public func immutableReleasesRepositories(of org: String, perPage: Int = 100) -> Paginated<Repository> {
        client.paginate(
            .wrappedList(
                path(org, "/settings/immutable-releases/repositories"), key: "repositories", query: .query(("per_page", perPage))))
    }

    /// Replaces the chosen repositories. `PUT /orgs/{org}/settings/immutable-releases/repositories`
    public func setImmutableReleasesRepositories(_ ids: [Int], in org: String) async throws(GitHubError) {
        struct Body: Encodable, Sendable {
            let ids: [Int]
            enum CodingKeys: String, CodingKey { case ids = "selected_repository_ids" }
        }
        try await client.value(
            GitHubRequest<Void>(.put, path(org, "/settings/immutable-releases/repositories"), body: Body(ids: ids)))
    }

    /// Adds a repository to the chosen set. `PUT /orgs/{org}/settings/immutable-releases/repositories/{repository_id}`
    public func enableImmutableReleases(forRepository id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, path(org, "/settings/immutable-releases/repositories/\(id)")))
    }

    /// Removes a repository from the chosen set. `DELETE /orgs/{org}/settings/immutable-releases/repositories/{repository_id}`
    public func disableImmutableReleases(forRepository id: Int, in org: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, path(org, "/settings/immutable-releases/repositories/\(id)")))
    }

    // MARK: API insights

    /// Total and rate-limited request counts. `GET /orgs/{org}/insights/api/summary-stats[/users/{user_id} | /{actor_type}/{actor_id}]`
    public func apiUsageSummary(
        in org: String, for scope: APIUsageScope = .organization, during window: APIUsageWindow
    ) async throws(GitHubError) -> APIUsageSummary {
        try await client.value(GitHubRequest(.get, path(org, scope.path("/insights/api/summary-stats")), query: window.query))
    }

    /// Request counts broken down over time. `GET /orgs/{org}/insights/api/time-stats[/users/{user_id} | /{actor_type}/{actor_id}]`
    public func apiUsageOverTime(
        in org: String, for scope: APIUsageScope = .organization, during window: APIUsageWindow, every interval: APIUsageInterval
    ) async throws(GitHubError) -> [APIUsageSample] {
        try await client.value(
            GitHubRequest(
                .get, path(org, scope.path("/insights/api/time-stats")),
                query: window.query + .query(("timestamp_increment", interval))))
    }

    /// Requests per API route for one actor. `GET /orgs/{org}/insights/api/route-stats/{actor_type}/{actor_id}`
    public func apiRouteUsage(
        in org: String, by actor: APIActor, during window: APIUsageWindow, sortedBy sort: APIUsageSort? = nil,
        ascending: Bool = false, routeContaining substring: String? = nil, perPage: Int = 100
    ) -> Paginated<APIRouteUsage> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/insights/api/route-stats/\(actor.pathComponent)"),
                query: window.query + insightsQuery(sort, ascending, ("api_route_substring", substring), perPage)))
    }

    /// Requests per subject, such as a repository. `GET /orgs/{org}/insights/api/subject-stats`
    public func apiSubjectUsage(
        in org: String, during window: APIUsageWindow, sortedBy sort: APIUsageSort? = nil, ascending: Bool = false,
        subjectContaining substring: String? = nil, perPage: Int = 100
    ) -> Paginated<APISubjectUsage> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/insights/api/subject-stats"),
                query: window.query + insightsQuery(sort, ascending, ("subject_name_substring", substring), perPage)))
    }

    /// Requests per app or token acting for a user. `GET /orgs/{org}/insights/api/user-stats/{user_id}`
    public func apiActorUsage(
        in org: String, forUser userID: Int, during window: APIUsageWindow, sortedBy sort: APIUsageSort? = nil,
        ascending: Bool = false, actorContaining substring: String? = nil, perPage: Int = 100
    ) -> Paginated<APIActorUsage> {
        client.paginate(
            GitHubRequest(
                .get, path(org, "/insights/api/user-stats/\(userID)"),
                query: window.query + insightsQuery(sort, ascending, ("actor_name_substring", substring), perPage)))
    }

    private func insightsQuery(
        _ sort: APIUsageSort?, _ ascending: Bool, _ filter: (String, String?), _ perPage: Int
    ) -> [URLQueryItem] {
        .query(("sort", sort), ("direction", ascending ? "asc" : "desc"), (filter.0, filter.1), ("per_page", perPage))
    }
}

/// The PUT body: a definition without its name, which is in the path.
private struct PropertyDefinitionBody: Encodable, Sendable {
    let property: CustomProperty
    init(_ property: CustomProperty) { self.property = property }

    enum CodingKeys: String, CodingKey {
        case valueType = "value_type"
        case required, description
        case defaultValue = "default_value"
        case allowedValues = "allowed_values"
        case valuesEditableBy = "values_editable_by"
        case requireExplicitValues = "require_explicit_values"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(property.valueType, forKey: .valueType)
        try c.encodeIfPresent(property.required, forKey: .required)
        try c.encodeIfPresent(property.description, forKey: .description)
        try c.encodeIfPresent(property.defaultValue, forKey: .defaultValue)
        try c.encodeIfPresent(property.allowedValues, forKey: .allowedValues)
        try c.encodeIfPresent(property.valuesEditableBy, forKey: .valuesEditableBy)
        try c.encodeIfPresent(property.requireExplicitValues, forKey: .requireExplicitValues)
    }
}

private struct PropertyValuesBody: Encodable, Sendable {
    let repositoryNames: [String]
    let properties: [CustomPropertyValue]

    enum CodingKeys: String, CodingKey {
        case properties
        case repositoryNames = "repository_names"
    }
}

private struct ExternalValuesBody: Encodable, Sendable {
    struct Entry: Encodable, Sendable {
        let repositoryName: String
        let value: String?

        enum CodingKeys: String, CodingKey {
            case value
            case repositoryName = "repository_name"
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(repositoryName, forKey: .repositoryName)
            try c.encode(value, forKey: .value)
        }
    }

    let repositoryValues: [Entry]

    init(_ values: [String: String?]) {
        repositoryValues = values.sorted { $0.key < $1.key }.map { Entry(repositoryName: $0.key, value: $0.value) }
    }

    enum CodingKeys: String, CodingKey { case repositoryValues = "repository_values" }
}
