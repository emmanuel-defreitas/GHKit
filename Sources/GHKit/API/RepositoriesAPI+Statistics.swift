import Foundation

// Traffic and commit statistics.
extension RepositoriesAPI {
    // MARK: Traffic

    /// Page views over the last 14 days. Needs push access. `GET /repos/{owner}/{repo}/traffic/views`
    public func views(_ owner: String, _ name: String, per period: TrafficPeriod = .day) async throws(GitHubError) -> RepositoryTraffic {
        try await client.value(GitHubRequest(.get, path(owner, name, "/traffic/views"), query: .query(("per", period))))
    }

    /// Clones over the last 14 days. Needs push access. `GET /repos/{owner}/{repo}/traffic/clones`
    public func clones(_ owner: String, _ name: String, per period: TrafficPeriod = .day) async throws(GitHubError) -> RepositoryTraffic {
        try await client.value(GitHubRequest(.get, path(owner, name, "/traffic/clones"), query: .query(("per", period))))
    }

    /// The 10 most viewed pages over the last 14 days. `GET /repos/{owner}/{repo}/traffic/popular/paths`
    public func popularContent(_ owner: String, _ name: String) async throws(GitHubError) -> [PopularContent] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/traffic/popular/paths")))
    }

    /// The 10 sites that sent the most visitors over the last 14 days. `GET /repos/{owner}/{repo}/traffic/popular/referrers`
    public func referrers(_ owner: String, _ name: String) async throws(GitHubError) -> [TrafficReferrer] {
        try await client.value(GitHubRequest(.get, path(owner, name, "/traffic/popular/referrers")))
    }

    // MARK: Statistics
    //
    // GitHub computes statistics in the background and answers 202 until they're ready.
    // These methods return `nil` then; try again after a few seconds.
    // Repositories with 10,000 or more commits return empty additions and deletions.

    /// Lines added and deleted per week, for repositories with fewer than 10,000 commits.
    /// `GET /repos/{owner}/{repo}/stats/code_frequency`
    /// - Returns: The weeks, oldest first, or `nil` while GitHub computes them.
    public func codeFrequency(_ owner: String, _ name: String) async throws(GitHubError) -> [WeeklyCodeFrequency]? {
        try await client.valueUnlessAccepted(path(owner, name, "/stats/code_frequency"), empty: [])
    }

    /// Commits per day for the last 52 weeks. `GET /repos/{owner}/{repo}/stats/commit_activity`
    /// - Returns: The weeks, oldest first, or `nil` while GitHub computes them.
    public func commitActivity(_ owner: String, _ name: String) async throws(GitHubError) -> [WeeklyCommitActivity]? {
        try await client.valueUnlessAccepted(path(owner, name, "/stats/commit_activity"), empty: [])
    }

    /// The top 100 contributors' weekly activity. `GET /repos/{owner}/{repo}/stats/contributors`
    /// - Returns: The contributors, or `nil` while GitHub computes them.
    public func contributorStatistics(_ owner: String, _ name: String) async throws(GitHubError) -> [ContributorStatistics]? {
        try await client.valueUnlessAccepted(path(owner, name, "/stats/contributors"), empty: [])
    }

    /// Weekly commit counts for the last 52 weeks, for everyone and for the owner.
    /// `GET /repos/{owner}/{repo}/stats/participation`
    /// - Returns: The counts, or `nil` while GitHub computes them.
    public func participation(_ owner: String, _ name: String) async throws(GitHubError) -> ParticipationStatistics? {
        try await client.valueUnlessAccepted(path(owner, name, "/stats/participation"))
    }

    /// Commits in each hour of the week. `GET /repos/{owner}/{repo}/stats/punch_card`
    /// - Returns: The hours, or `nil` while GitHub computes them.
    public func punchCard(_ owner: String, _ name: String) async throws(GitHubError) -> [PunchCardHour]? {
        try await client.valueUnlessAccepted(path(owner, name, "/stats/punch_card"), empty: [])
    }
}

extension GitHubClient {
    /// Fetches a value GitHub computes in the background.
    ///
    /// Returns `nil` for `202 Accepted`, and `empty` for `204 No Content`, which GitHub sends for empty repositories.
    func valueUnlessAccepted<Value: Decodable & Sendable>(
        _ path: String, empty: Value? = nil
    ) async throws(GitHubError) -> Value? {
        let response = try await send(GitHubRequest<Data>(method: .get, target: .path(path)) { $0 })
        switch response.metadata.statusCode {
        case 202: return nil
        case 204: return empty
        default:
            if response.value.isEmpty { return empty }
            do {
                return try GitHubJSON.decoder().decode(Value.self, from: response.value)
            } catch {
                throw .decoding(type: String(describing: Value.self), underlying: error)
            }
        }
    }
}
