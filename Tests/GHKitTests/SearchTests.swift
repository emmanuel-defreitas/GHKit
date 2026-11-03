import Foundation
import Testing

@testable import GHKit

@Suite("Search")
struct SearchTests {
    @Test func searchesCodeAndCommits() async throws {
        let transport = MockTransport { request, _ in
            .fixture(request.url!.path().hasSuffix("code") ? "code-search-result-item-paginated" : "commit-search-result-item-paginated")
        }
        let search = makeClient(transport).search
        let files = try await search.code("addClass in:file language:js repo:jquery/jquery", textMatches: true).collect()
        #expect(files.first?.path == "src/attributes/classes.js")
        #expect(files.first?.repository?.fullName == "jquery/jquery")
        #expect(files.first?.score == 1)

        let commits = try await search.commits("repo:octocat/Spoon-Knife css", sort: .authorDate, ascending: true).collect()
        #expect(commits.first?.sha == "bb4cc8d3b2e14b3af5df699876dd4ff3acd00b7f")
        #expect(commits.first?.repository?.fullName != nil)

        #expect(transport.requests[0].route == "GET /search/code")
        #expect(transport.requests[0].queryItems == ["q": "addClass in:file language:js repo:jquery/jquery", "per_page": "100"])
        #expect(transport.requests[0].value(forHTTPHeaderField: "Accept") == "application/vnd.github.text-match+json")
        #expect(transport.requests[1].queryItems == ["q": "repo:octocat/Spoon-Knife css", "sort": "author-date", "order": "asc", "per_page": "100"])
        #expect(transport.requests[1].value(forHTTPHeaderField: "Accept") != "application/vnd.github.text-match+json")
    }

    @Test func searchesIssues() async throws {
        let transport = MockTransport(.fixture("issue-search-result-item-paginated"))
        let search = makeClient(transport).search
        let issues = try await search.issues(
            "windows label:bug language:python state:open", sort: .thumbsUpReactions, ascending: false, advanced: true,
            mode: .hybrid
        ).collect()
        #expect(issues.first?.number == 132)
        #expect(issues.first?.title == "Line Number Indexes Beyond 20 Not Displayed")
        #expect(issues.first?.textMatches == nil)
        #expect(
            transport.requests[0].queryItems == [
                "q": "windows label:bug language:python state:open", "sort": "reactions-+1", "order": "desc",
                "advanced_search": "true", "search_type": "hybrid", "per_page": "100",
            ])
    }

    @Test func searchesLabelsRepositoriesTopicsAndUsers() async throws {
        let transport = MockTransport { request, _ in
            let kind = request.url!.lastPathComponent
            let fixture = ["labels": "label", "repositories": "repo", "topics": "topic", "users": "user"][kind]!
            return .fixture("\(fixture)-search-result-item-paginated")
        }
        let search = makeClient(transport).search
        let labels = try await search.labels("bug defect enhancement", inRepository: 64778136, sort: .created).collect()
        #expect(labels.first?.name == "enhancement")
        let repositories = try await search.repositories("tetris language:assembly", sort: .helpWantedIssues).collect()
        #expect(repositories.first?.fullName == "dtrupenn/Tetris")
        let topics = try await search.topics("ruby is:featured").collect()
        #expect(topics.first?.displayName == "Ruby")
        #expect(topics.first?.isFeatured == true)
        let users = try await search.users("tom repos:>42 followers:>1000", sort: .followers).collect()
        #expect(users.first?.login == "mojombo")

        #expect(transport.requests.map(\.path) == ["/search/labels", "/search/repositories", "/search/topics", "/search/users"])
        #expect(
            transport.requests[0].queryItems == [
                "repository_id": "64778136", "q": "bug defect enhancement", "sort": "created", "per_page": "100",
            ])
        #expect(transport.requests[1].queryItems["sort"] == "help-wanted-issues")
        #expect(transport.requests[3].queryItems["sort"] == "followers")
    }

    @Test func summarizesASearch() async throws {
        let transport = MockTransport(.fixture("issue-search-result-item-paginated-lexical-fallback"))
        let summary = try await makeClient(transport).search.issues("is:issue crash", mode: .semantic, perPage: 50).summary()
        #expect(summary.totalCount > 0)
        #expect(summary.searchType == "lexical")
        #expect(summary.lexicalFallbackReasons?.isEmpty == false)
        #expect(transport.requests[0].queryItems == ["q": "is:issue crash", "search_type": "semantic", "per_page": "1"])
    }

    @Test func textMatchesDecode() throws {
        let result = try GitHubJSON.decoder().decode(
            SearchResult<IssueLabel>.self,
            from: Data(
                #"""
                {"name": "bug", "score": 2.5, "text_matches": [{"object_url": "https://api.github.com/x", "object_type": "Label",
                 "property": "name", "fragment": "bug", "matches": [{"text": "bug", "indices": [0, 3]}]}]}
                """#.utf8))
        #expect(result.score == 2.5)
        #expect(result.textMatches?.first?.property == "name")
        #expect(result.textMatches?.first?.matches?.first?.indices == [0, 3])
    }

    @Test func resultsRoundTrip() throws {
        let data = loadFixture("repo-search-result-item-paginated")
        let wrapper = try GitHubJSON.decoder().decode([String: JSONValue].self, from: data)
        let item = try GitHubJSON.encoder().encode(wrapper["items"]?[0])
        let result = try GitHubJSON.decoder().decode(SearchResult<Repository>.self, from: item)
        let again = try GitHubJSON.decoder().decode(SearchResult<Repository>.self, from: GitHubJSON.encoder().encode(result))
        #expect(again == result)
        #expect(result.item.fullName == result.fullName)
    }
}
