import Foundation
import Testing

@testable import GHKitCore
@testable import GHKitIssues
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitRepositories

@Suite("Routed authenticator")
struct RoutedAuthenticatorTests {
    let project = String(decoding: loadFixture("projects-v2"), as: UTF8.self)

    /// Answers every request with an empty list and records the token it carried.
    func emptyLists() -> MockTransport {
        MockTransport { _, _ in .json("[]") }
    }

    func tokens(_ transport: MockTransport) -> [String] {
        transport.requests.map { ($0.value(forHTTPHeaderField: "Authorization") ?? "").replacingOccurrences(of: "Bearer ", with: "") }
    }

    @Test func picksCredentialsByDomain() async throws {
        let transport = emptyLists()
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), domains: [.organizations: .token("admin")]))
        _ = try await github.organizations.members(of: "acme").firstPage()
        _ = try await github.repositories.branches("acme", "app").firstPage()
        _ = try await github.issues.labels("acme", "app").firstPage()
        #expect(tokens(transport) == ["admin", "main", "main"])
    }

    @Test func ownerBeatsDomainAndDomainOwnerBeatsBoth() async throws {
        let transport = emptyLists()
        var routed = RoutedAuthenticator(default: .token("main"), domains: [.issues: .token("issues")])
        routed.use(.token("acme"), forOwner: "Acme")
        routed.use(.token("acme-issues"), for: .issues, owner: "acme")
        let github = makeClient(transport, authenticator: routed)

        _ = try await github.issues.labels("ACME", "app").firstPage()
        _ = try await github.repositories.branches("acme", "app").firstPage()
        _ = try await github.issues.labels("octocat", "app").firstPage()
        _ = try await github.repositories.branches("octocat", "app").firstPage()
        #expect(tokens(transport) == ["acme-issues", "acme", "issues", "main"])
    }

    @Test func nextPagesKeepTheFirstPagesOwner() async throws {
        // GitHub's next links can name the repository by ID, not by owner.
        let transport = MockTransport { _, index in
            index == 0
                ? .json("[]", headers: ["Link": #"<https://api.github.com/repositories/42/labels?page=2>; rel="next""#])
                : .json("[]")
        }
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), owners: ["acme": .token("acme")]))
        _ = try await github.issues.labels("acme", "app").collect()
        #expect(transport.requests.map(\.path) == ["/repos/acme/app/labels", "/repositories/42/labels"])
        #expect(tokens(transport) == ["acme", "acme"])
    }

    @Test func graphQLCallsUseTheProjectOwner() async throws {
        let item = try GitHubJSON.decoder().decode(ProjectItem.self, from: loadFixture("projects-v2-item-simple"))
        let transport = MockTransport { [project] request, _ in
            request.path == "/graphql" ? .json(#"{"data":{"result":{"item":{"id":"x"}}}}"#) : .json(project)
        }
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), owners: ["acme": .token("acme")]))
        try await github.projects(.organization("acme")).archive(item, in: 2)
        #expect(transport.requests.last?.path == "/graphql")
        #expect(tokens(transport) == ["acme", "acme"])
    }

    @Test func customRequestsUseTheDefault() async throws {
        let transport = emptyLists()
        let github = makeClient(transport, authenticator: .routed(default: .token("main"), domains: [.issues: .token("issues")]))
        _ = try await github.value(GitHubRequest<[IssueLabel]>(.get, "/user/labels"))
        #expect(tokens(transport) == ["main"])
    }

    @Test func refreshesTheCredentialItChose() async throws {
        actor Rotating: Authenticator {
            var token = "old"
            var refreshes = 0
            func authorization() async throws(GitHubError) -> String? { "Bearer \(token)" }
            func refreshAfterUnauthorized() async throws(GitHubError) -> Bool {
                refreshes += 1
                token = "new"
                return true
            }
        }
        let transport = MockTransport { request, _ in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer new"
                ? .json("[]") : .json(#"{"message":"Bad credentials"}"#, status: 401)
        }
        let rotating = Rotating()
        let main = Rotating()
        let github = makeClient(transport, authenticator: .routed(default: main, domains: [.issues: rotating]))
        _ = try await github.issues.labels("acme", "app").firstPage()
        #expect(await rotating.refreshes == 1)
        #expect(await main.refreshes == 0)
    }

    @Test func requestContextComesFromTheClientAndPath() {
        let github = makeClient(emptyLists())
        let labels = GitHubRequest<[IssueLabel]>(.get, "/repos/a%20b/app/labels")
        #expect(github.issues.client.context(for: labels) == GitHubRequestContext(domain: .issues, owner: "a b", method: .get))
        let me = GitHubRequest<[IssueLabel]>(.get, "/user/issues")
        #expect(github.context(for: me) == GitHubRequestContext(domain: nil, owner: nil, method: .get))
        let scoped = github.scoped(to: .projects, owner: "acme")
        #expect(scoped.context(for: me).owner == "acme")
    }
}
