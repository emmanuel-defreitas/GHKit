import Foundation

extension GitHubClient {
    /// Activity endpoints: events, feeds, notifications, stars, and watching.
    public var activity: ActivityAPI { ActivityAPI(client: self) }
}

/// Activity endpoints: events, feeds, notifications, stars, and watching. Reach them with `github.activity`.
///
///     for try await event in github.activity.events(.repository(owner: "octocat", name: "Hello-World")) {
///         print(event.type?.rawValue ?? "", event.actor.login)
///     }
public struct ActivityAPI: Sendable {
    let client: GitHubClient

    private func repositoryPath(_ owner: String, _ name: String, _ rest: String) -> String {
        "/repos/\(escape(owner))/\(escape(name))\(rest)"
    }

    private func threadPath(_ id: String, _ rest: String = "") -> String {
        "/notifications/threads/\(escape(id))\(rest)"
    }

    private static let starMediaType = "application/vnd.github.star+json"

    // MARK: Events

    /// Recent events from a source, newest first. GitHub keeps 30 days of events, up to 300 per source.
    /// `GET /events`, `GET /repos/{owner}/{repo}/events`, `GET /users/{username}/events`, and the other event paths,
    /// depending on `source`.
    public func events(_ source: EventSource = .everyone, perPage: Int = 100) -> Paginated<GitHubEvent> {
        var request = GitHubRequest<[GitHubEvent]>(.get, source.path, query: .query(("per_page", perPage)))
        // GitHub's description lists no `Link` header here, so count pages if one is missing.
        request.numberedPageSize = perPage
        return client.paginate(request)
    }

    /// The signed-in user's Atom feed URLs. `GET /feeds`
    public func feeds() async throws(GitHubError) -> Feeds {
        try await client.value(GitHubRequest(.get, "/feeds"))
    }

    // MARK: Notifications

    /// The signed-in user's notifications, newest first. Unread ones only, unless the filter says otherwise.
    /// `GET /notifications`
    public func notifications(matching filter: NotificationFilter = NotificationFilter(), perPage: Int = 50)
        -> Paginated<NotificationThread>
    {
        client.paginate(GitHubRequest(.get, "/notifications", query: filter.query + .query(("per_page", perPage))))
    }

    /// The signed-in user's notifications in one repository. `GET /repos/{owner}/{repo}/notifications`
    public func notifications(
        in owner: String, _ name: String, matching filter: NotificationFilter = NotificationFilter(), perPage: Int = 50
    ) -> Paginated<NotificationThread> {
        let query = filter.query + .query(("per_page", perPage))
        return client.paginate(GitHubRequest(.get, repositoryPath(owner, name, "/notifications"), query: query))
    }

    /// Marks notifications as read. GitHub may finish the work in the background. `PUT /notifications`
    /// - Parameter lastReadAt: Only notifications updated before this time. Leave `nil` for all of them.
    public func markNotificationsRead(before lastReadAt: Date? = nil) async throws(GitHubError) {
        let body = MarkRead(lastReadAt: lastReadAt, read: true)
        try await client.value(GitHubRequest<Void>(.put, "/notifications", body: body))
    }

    /// Marks a repository's notifications as read. `PUT /repos/{owner}/{repo}/notifications`
    /// - Parameter lastReadAt: Only notifications updated before this time. Leave `nil` for all of them.
    public func markNotificationsRead(in owner: String, _ name: String, before lastReadAt: Date? = nil) async throws(GitHubError) {
        let body = MarkRead(lastReadAt: lastReadAt, read: nil)
        try await client.value(GitHubRequest<Void>(.put, repositoryPath(owner, name, "/notifications"), body: body))
    }

    private struct MarkRead: Encodable, Sendable {
        let lastReadAt: Date?
        let read: Bool?
        enum CodingKeys: String, CodingKey {
            case read
            case lastReadAt = "last_read_at"
        }
    }

    /// One notification. `GET /notifications/threads/{thread_id}`
    public func thread(id: String) async throws(GitHubError) -> NotificationThread {
        try await client.value(GitHubRequest(.get, threadPath(id)))
    }

    /// Marks a notification as read. `PATCH /notifications/threads/{thread_id}`
    public func markThreadRead(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.patch, threadPath(id)))
    }

    /// Marks a notification as done, which removes it from the inbox. `DELETE /notifications/threads/{thread_id}`
    public func markThreadDone(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, threadPath(id)))
    }

    /// Whether the signed-in user follows a notification's conversation.
    /// `GET /notifications/threads/{thread_id}/subscription`
    public func threadSubscription(id: String) async throws(GitHubError) -> ThreadSubscription {
        try await client.value(GitHubRequest(.get, threadPath(id, "/subscription")))
    }

    /// Follows a notification's conversation, or mutes it with `ignored: true`.
    /// `PUT /notifications/threads/{thread_id}/subscription`
    @discardableResult
    public func subscribeToThread(id: String, ignored: Bool = false) async throws(GitHubError) -> ThreadSubscription {
        try await client.value(GitHubRequest(.put, threadPath(id, "/subscription"), body: ["ignored": ignored]))
    }

    /// Stops following a notification's conversation. You'll still be notified if you're mentioned or take part.
    /// `DELETE /notifications/threads/{thread_id}/subscription`
    public func unsubscribeFromThread(id: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, threadPath(id, "/subscription")))
    }

    // MARK: Stars

    /// The people who starred a repository. `GET /repos/{owner}/{repo}/stargazers`
    public func stargazers(of owner: String, _ name: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, repositoryPath(owner, name, "/stargazers"), query: .query(("per_page", perPage))))
    }

    /// The people who starred a repository, with when they did. `GET /repos/{owner}/{repo}/stargazers`
    public func stars(on owner: String, _ name: String, perPage: Int = 100) -> Paginated<Stargazer> {
        var request = GitHubRequest<[Stargazer]>(
            .get, repositoryPath(owner, name, "/stargazers"), query: .query(("per_page", perPage)))
        request.headers["Accept"] = Self.starMediaType
        return client.paginate(request)
    }

    /// How many people starred a repository. `GET /repos/{owner}/{repo}/stargazers/count`
    public func stargazerCount(of owner: String, _ name: String) async throws(GitHubError) -> Int {
        struct Count: Decodable, Sendable { let count: Int }
        let count: Count = try await client.value(GitHubRequest(.get, repositoryPath(owner, name, "/stargazers/count")))
        return count.count
    }

    /// New stars per week. `GET /repos/{owner}/{repo}/stargazers/history`
    /// - Parameter perPage: At most 30, unlike the other star lists.
    public func starHistory(of owner: String, _ name: String, perPage: Int = 30) -> Paginated<StarHistoryWeek> {
        client.paginate(
            GitHubRequest(.get, repositoryPath(owner, name, "/stargazers/history"), query: .query(("per_page", perPage))))
    }

    private func starredPath(_ login: String?) -> String {
        login.map { "/users/\(escape($0))/starred" } ?? "/user/starred"
    }

    private func starredQuery(_ sort: StarSort, _ ascending: Bool?, _ perPage: Int) -> [URLQueryItem] {
        .query(("sort", sort), ("direction", ascending.map { $0 ? "asc" : "desc" }), ("per_page", perPage))
    }

    /// Repositories a user starred. `GET /user/starred`, or `GET /users/{username}/starred` when you pass a login.
    /// - Parameter login: The user, or `nil` for the signed-in user.
    public func starredRepositories(
        by login: String? = nil, sort: StarSort = .created, ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<Repository> {
        client.paginate(GitHubRequest(.get, starredPath(login), query: starredQuery(sort, ascending, perPage)))
    }

    /// Repositories a user starred, with when they did.
    /// `GET /user/starred`, or `GET /users/{username}/starred` when you pass a login.
    /// - Parameter login: The user, or `nil` for the signed-in user.
    public func stars(
        by login: String? = nil, sort: StarSort = .created, ascending: Bool? = nil, perPage: Int = 100
    ) -> Paginated<StarredRepository> {
        var request = GitHubRequest<[StarredRepository]>(.get, starredPath(login), query: starredQuery(sort, ascending, perPage))
        request.headers["Accept"] = Self.starMediaType
        return client.paginate(request)
    }

    /// Whether the signed-in user starred a repository. `GET /user/starred/{owner}/{repo}`
    public func isStarred(_ owner: String, _ name: String) async throws(GitHubError) -> Bool {
        try await client.exists("/user/starred/\(escape(owner))/\(escape(name))")
    }

    /// Stars a repository as the signed-in user. `PUT /user/starred/{owner}/{repo}`
    public func star(_ owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.put, "/user/starred/\(escape(owner))/\(escape(name))"))
    }

    /// Removes the signed-in user's star. `DELETE /user/starred/{owner}/{repo}`
    public func unstar(_ owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, "/user/starred/\(escape(owner))/\(escape(name))"))
    }

    // MARK: Watching

    /// The people watching a repository. `GET /repos/{owner}/{repo}/subscribers`
    public func watchers(of owner: String, _ name: String, perPage: Int = 100) -> Paginated<SimpleUser> {
        client.paginate(GitHubRequest(.get, repositoryPath(owner, name, "/subscribers"), query: .query(("per_page", perPage))))
    }

    /// Repositories a user watches. `GET /user/subscriptions`, or `GET /users/{username}/subscriptions` when you pass a login.
    /// - Parameter login: The user, or `nil` for the signed-in user.
    public func watchedRepositories(by login: String? = nil, perPage: Int = 100) -> Paginated<Repository> {
        let path = login.map { "/users/\(escape($0))/subscriptions" } ?? "/user/subscriptions"
        return client.paginate(GitHubRequest(.get, path, query: .query(("per_page", perPage))))
    }

    /// How the signed-in user watches a repository, or `nil` if they don't. `GET /repos/{owner}/{repo}/subscription`
    public func subscription(to owner: String, _ name: String) async throws(GitHubError) -> RepositorySubscription? {
        do {
            return try await client.value(GitHubRequest(.get, repositoryPath(owner, name, "/subscription")))
        } catch .notFound(_, _) {
            return nil
        }
    }

    /// Watches a repository, or ignores all its notifications with `ignored: true`.
    /// `PUT /repos/{owner}/{repo}/subscription`
    @discardableResult
    public func watch(_ owner: String, _ name: String, ignored: Bool = false) async throws(GitHubError) -> RepositorySubscription {
        let body = ["subscribed": !ignored, "ignored": ignored]
        return try await client.value(GitHubRequest(.put, repositoryPath(owner, name, "/subscription"), body: body))
    }

    /// Stops watching a repository. `DELETE /repos/{owner}/{repo}/subscription`
    public func unwatch(_ owner: String, _ name: String) async throws(GitHubError) {
        try await client.value(GitHubRequest<Void>(.delete, repositoryPath(owner, name, "/subscription")))
    }
}
