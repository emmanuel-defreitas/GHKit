import Foundation
import Testing

@testable import GHKit

@Suite("Client")
struct ClientTests {
    @Test func sendsStandardHeaders() async throws {
        let transport = MockTransport(.fixture("private-user"))
        let user = try await makeClient(transport).users.authenticated()

        #expect(user.login == "octocat")
        #expect(user.plan?.privateRepos == 20)
        let request = try #require(transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.github.com/user")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("GHKit/") == true)
    }

    @Test func anonymousClientSendsNoAuthorization() async throws {
        let transport = MockTransport(.fixture("private-user"))
        _ = try await makeClient(transport, authenticator: AnonymousAuthenticator()).users.user("octocat")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(transport.requests.first?.path == "/users/octocat")
    }

    @Test func enterpriseServerPaths() async throws {
        let transport = MockTransport(.fixture("private-user"))
        var client = GitHubClient(
            token: "t",
            configuration: GitHubConfiguration(server: .enterpriseServer(URL(string: "https://ghe.example.com")!)),
            transport: transport
        )
        client.sleep = { _ in }
        _ = try await client.users.authenticated()
        #expect(transport.requests.first?.url?.absoluteString == "https://ghe.example.com/api/v3/user")
    }

    @Test func plusSignsInQueriesAreEscaped() async throws {
        let transport = MockTransport(.json("[]"))
        _ = try await makeClient(transport).projects(.organization("acme")).list(matching: "is:open c++").collect()
        let query = try #require(transport.requests.first?.url?.query())
        #expect(query.contains("c%2B%2B"))
    }

    @Test func mapsNotFound() async {
        let transport = MockTransport(.json(#"{"message":"Not Found","documentation_url":"https://docs.github.com"}"#, status: 404))
        await #expect {
            _ = try await makeClient(transport).users.user("ghost")
        } throws: { error in
            guard case .notFound(let body, let metadata) = error as? GitHubError else { return false }
            return body?.message == "Not Found" && metadata.statusCode == 404
        }
    }

    @Test func mapsValidationErrors() async {
        let body = #"{"message":"Validation Failed","errors":[{"resource":"Field","field":"name","code":"missing"},"Name is too long"]}"#
        let transport = MockTransport(.json(body, status: 422))
        do {
            _ = try await makeClient(transport).projects(.organization("acme")).addField(.text(name: ""), to: 1)
            Issue.record("Expected an error")
        } catch {
            guard case .validationFailed(let body?, _) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(body.errors?.count == 2)
            #expect(body.summary == "Validation Failed — Field name missing — Name is too long")
        }
    }

    @Test func detectsPrimaryRateLimit() async {
        let reset = Int(Date.now.timeIntervalSince1970) + 30
        let transport = MockTransport(
            .json(
                #"{"message":"API rate limit exceeded"}"#, status: 403,
                headers: [
                    "X-RateLimit-Limit": "5000", "X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "\(reset)",
                ]))
        do {
            _ = try await makeClient(transport).users.authenticated()
            Issue.record("Expected an error")
        } catch {
            guard case .rateLimited(let limit, let retryAfter, _, _) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(limit?.remaining == 0)
            #expect(retryAfter.map { $0 > .zero && $0 <= .seconds(31) } == true)
        }
    }

    @Test func retriesSecondaryRateLimitUsingRetryAfter() async throws {
        let transport = MockTransport(
            .json(#"{"message":"You have exceeded a secondary rate limit"}"#, status: 403, headers: ["Retry-After": "2"]),
            .fixture("private-user")
        )
        let sleeps = SleepRecorder()
        var client = makeClient(transport, retryPolicy: .default)
        client.sleep = sleeps.sleep

        let user = try await client.users.authenticated()
        #expect(user.login == "octocat")
        #expect(transport.requests.count == 2)
        #expect(sleeps.durations == [.seconds(2)])
    }

    @Test func retriesServerErrorsForGetOnly() async throws {
        let getTransport = MockTransport(.json("{}", status: 503), .fixture("private-user"))
        _ = try await makeClient(getTransport, retryPolicy: .default).users.authenticated()
        #expect(getTransport.requests.count == 2)

        let postTransport = MockTransport(.json(#"{"message":"unavailable"}"#, status: 503))
        await #expect(throws: GitHubError.self) {
            _ = try await makeClient(postTransport, retryPolicy: .default)
                .projects(.organization("acme")).addItem(.issue(id: 1), to: 1)
        }
        #expect(postTransport.requests.count == 1)
    }

    @Test func refreshesOnceAfterUnauthorized() async throws {
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
                ? .fixture("private-user")
                : .json(#"{"message":"Bad credentials"}"#, status: 401)
        }
        let auth = Rotating()
        _ = try await makeClient(transport, authenticator: auth).users.authenticated()
        #expect(await auth.refreshes == 1)
        #expect(transport.requests.count == 2)
    }

    @Test func paginationFollowsLinkHeaders() async throws {
        let page2 = "https://api.github.com/orgs/acme/projectsV2?after=cursor2"
        let project = String(decoding: loadFixture("projects-v2"), as: UTF8.self)
        let transport = MockTransport { request, _ in
            if request.url?.query()?.contains("after=cursor2") == true {
                return .json("[\(project)]")
            }
            return .json("[\(project),\(project)]", headers: ["Link": "<\(page2)>; rel=\"next\""])
        }
        let acme = makeClient(transport).projects(.organization("acme"))

        let all = try await acme.list().collect()
        #expect(all.count == 3)
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].queryItems["per_page"] == "30")

        let limited = try await acme.list().collect(limit: 1)
        #expect(limited.count == 1)
        #expect(transport.requests.count == 3)  // stopped after the first page

        var pageSizes: [Int] = []
        for try await page in acme.list().pages { pageSizes.append(page.items.count) }
        #expect(pageSizes == [2, 1])
    }

    @Test func manualPaging() async throws {
        let transport = MockTransport(
            .json("[]", headers: ["Link": #"<https://api.github.com/orgs/acme/projectsV2?after=x>; rel="next""#]),
            .json("[]")
        )
        let client = makeClient(transport)
        let request = client.projects(.organization("acme")).listRequest()
        let first = try await client.page(request)
        let next = try #require(first.next)
        let second = try await client.page(request, at: next)
        #expect(second.hasNextPage == false)
        #expect(transport.requests[1].url?.absoluteString == "https://api.github.com/orgs/acme/projectsV2?after=x")
    }

    @Test func graphQLErrorsAreThrown() async {
        let transport = MockTransport(.json(#"{"data":null,"errors":[{"type":"NOT_FOUND","message":"Could not resolve"}]}"#))
        struct Viewer: Decodable, Sendable { let viewer: String }
        do {
            _ = try await makeClient(transport).graphQL("query { viewer { login } }", as: Viewer.self)
            Issue.record("Expected an error")
        } catch {
            guard case .graphQL(let errors) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(errors.first?.type == "NOT_FOUND")
        }
        #expect(transport.requests.first?.url?.absoluteString == "https://api.github.com/graphql")
    }

    @Test func decodingFailuresNameTheType() async {
        let transport = MockTransport(.json(#"{"unexpected":true}"#))
        do {
            _ = try await makeClient(transport).users.authenticated()
            Issue.record("Expected an error")
        } catch {
            guard case .decoding(let type, _) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect(type == "User")
        }
    }

    @Test func verifyAuthenticationReportsScopes() async throws {
        let transport = MockTransport(.fixture("private-user", headers: ["X-OAuth-Scopes": "repo, project"]))
        let status = try await makeClient(transport).verifyAuthentication()
        #expect(status.user.login == "octocat")
        #expect(status.hasScope(.project))
        #expect(!status.hasScope(.adminOrg))
    }

    @Test func rateLimitOverviewDecodes() async throws {
        let overview = try await makeClient(MockTransport(.fixture("rate-limit-overview"))).rateLimit()
        #expect(overview.core != nil)
        #expect(overview.graphQL != nil)
    }
}
