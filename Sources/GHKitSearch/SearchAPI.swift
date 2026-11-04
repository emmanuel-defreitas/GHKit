import Foundation
import GHKitCore

extension GitHubClient {
    /// Search endpoints.
    public var search: SearchAPI { SearchAPI(client: self) }
}

/// Search endpoints. Reach them with `github.search`.
///
/// Each method takes a query in GitHub's search syntax, such as `"swiftui language:swift stars:>100"`,
/// and returns the best matches first unless you pick a sort. GitHub returns at most 1,000 results per search,
/// and searches have their own, lower rate limit.
///
///     for try await result in github.search.repositories("swiftui language:swift").prefix(20) {
///         print(result.fullName, result.score ?? 0)
///     }
///
/// Call ``Paginated/summary()`` on a search for its total count.
///
/// Part of the `GHKitSearch` library.
public struct SearchAPI: Sendable {
    let client: GitHubClient

    private static let textMatchMediaType = "application/vnd.github.text-match+json"

    private func search<Item>(
        _ kind: String, _ query: [URLQueryItem], textMatches: Bool
    ) -> Paginated<SearchResult<Item>> {
        var request: GitHubRequest<[SearchResult<Item>]> = .wrappedList("/search/\(kind)", key: "items", query: query)
        if textMatches { request.headers["Accept"] = Self.textMatchMediaType }
        return client.paginate(request)
    }

    private func order(_ ascending: Bool?) -> String? {
        ascending.map { $0 ? "asc" : "desc" }
    }

    /// Files whose contents or paths match, in the default branch of each repository. `GET /search/code`
    /// - Parameter textMatches: Include the matched snippets in ``SearchResult/textMatches``.
    public func code(_ query: String, textMatches: Bool = false, perPage: Int = 100) -> Paginated<SearchResult<CodeFile>> {
        search("code", .query(("q", query), ("per_page", perPage)), textMatches: textMatches)
    }

    /// Commits whose messages or metadata match, in default branches. `GET /search/commits`
    public func commits(
        _ query: String, sort: CommitSearchSort? = nil, ascending: Bool? = nil, textMatches: Bool = false, perPage: Int = 100
    ) -> Paginated<SearchResult<Commit>> {
        search(
            "commits", .query(("q", query), ("sort", sort), ("order", order(ascending)), ("per_page", perPage)),
            textMatches: textMatches)
    }

    /// Issues and pull requests that match. The query needs `is:issue` or `is:pr`. `GET /search/issues`
    /// - Parameters:
    ///   - advanced: Use advanced search syntax, which supports `AND`, `OR`, and parentheses.
    ///   - mode: Match by meaning as well as words. Leave `nil` for plain word matching.
    public func issues(
        _ query: String, sort: IssueSearchSort? = nil, ascending: Bool? = nil, advanced: Bool? = nil,
        mode: IssueSearchMode? = nil, textMatches: Bool = false, perPage: Int = 100
    ) -> Paginated<SearchResult<GitHubIssue>> {
        let query: [URLQueryItem] = .query(
            ("q", query), ("sort", sort), ("order", order(ascending)), ("advanced_search", advanced), ("search_type", mode),
            ("per_page", perPage))
        return search("issues", query, textMatches: textMatches)
    }

    /// Labels in one repository whose names or descriptions match. `GET /search/labels`
    public func labels(
        _ query: String, inRepository repositoryID: Int, sort: LabelSearchSort? = nil, ascending: Bool? = nil,
        textMatches: Bool = false, perPage: Int = 100
    ) -> Paginated<SearchResult<IssueLabel>> {
        let query: [URLQueryItem] = .query(
            ("repository_id", repositoryID), ("q", query), ("sort", sort), ("order", order(ascending)), ("per_page", perPage))
        return search("labels", query, textMatches: textMatches)
    }

    /// Repositories that match. `GET /search/repositories`
    public func repositories(
        _ query: String, sort: RepositorySearchSort? = nil, ascending: Bool? = nil, textMatches: Bool = false,
        perPage: Int = 100
    ) -> Paginated<SearchResult<Repository>> {
        search(
            "repositories", .query(("q", query), ("sort", sort), ("order", order(ascending)), ("per_page", perPage)),
            textMatches: textMatches)
    }

    /// Topics that match. `GET /search/topics`
    public func topics(_ query: String, textMatches: Bool = false, perPage: Int = 100) -> Paginated<SearchResult<Topic>> {
        search("topics", .query(("q", query), ("per_page", perPage)), textMatches: textMatches)
    }

    /// Users and organizations that match. `GET /search/users`
    public func users(
        _ query: String, sort: UserSearchSort? = nil, ascending: Bool? = nil, textMatches: Bool = false, perPage: Int = 100
    ) -> Paginated<SearchResult<SimpleUser>> {
        search(
            "users", .query(("q", query), ("sort", sort), ("order", order(ascending)), ("per_page", perPage)),
            textMatches: textMatches)
    }
}

extension Paginated {
    /// How many items a search matches, and whether the search finished.
    ///
    /// This loads one result, so it counts against the search rate limit.
    public func summary<Item>() async throws(GitHubError) -> SearchSummary where Element == SearchResult<Item> {
        var query = request.query.filter { $0.name != "per_page" && $0.name != "page" }
        query.append(URLQueryItem(name: "per_page", value: "1"))
        let target: GitHubRequest<SearchSummary>.Target =
            switch request.target {
            case .path(let path): .path(path)
            case .url(let url): .url(url)
            }
        let summary = GitHubRequest<SearchSummary>(method: .get, target: target, query: query, headers: request.headers) { data in
            try GitHubJSON.decoder().decode(SearchSummary.self, from: data)
        }
        return try await client.value(summary)
    }
}
