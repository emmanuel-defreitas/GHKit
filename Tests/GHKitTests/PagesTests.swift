import Foundation
import Testing

@testable import GHKitActivity
@testable import GHKitApps
@testable import GHKitCore
@testable import GHKitGists
@testable import GHKitIssues
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitPullRequests
@testable import GHKitRepositories
@testable import GHKitSearch
@testable import GHKitUsers

@Suite("Pages")
struct PagesTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let site = try decoder.decode(PagesSite.self, from: loadFixture("page"))
        #expect(site.status == .built)
        #expect(site.cname == "developer.github.com")
        #expect(site.source == PagesSource(branch: "master", path: "/"))
        #expect(site.isPublic)
        #expect(site.protectedDomainState == .verified)
        #expect(site.httpsCertificate?.expiresAt == CalendarDate(year: 2021, month: 5, day: 22))

        let build = try decoder.decode(PagesBuild.self, from: loadFixture("page-build"))
        #expect(build.status == .built)
        #expect(build.errorMessage == nil)
        #expect(build.pusher?.login == "octocat")
        _ = try decoder.decode([PagesBuild].self, from: loadFixture("page-build-items"))
        #expect(try decoder.decode(QueuedPagesBuild.self, from: loadFixture("page-build-status")).status == .queued)

        let deployment = try decoder.decode(PagesDeployment.self, from: loadFixture("page-deployment"))
        #expect(deployment.id == "4fd754f7e594640989b406850d0bc8f06a121251")
        #expect(deployment.pageURL == "developer.github.com")
        let numbered = try decoder.decode(
            PagesDeployment.self, from: Data(#"{"id":42,"status_url":"https://api.github.com/x","page_url":"https://o.github.io"}"#.utf8))
        #expect(numbered.id == "42")

        let health = try decoder.decode(PagesHealthCheck.self, from: loadFixture("pages-health-check"))
        #expect(health.domain?.isValid == true)
        #expect(health.altDomain?.host == "www.example.com")
    }

    @Test func siteRequests() async throws {
        let transport = MockTransport { request, index in
            switch request.route {
            case "GET /repos/o/r/pages/health": index == 6 ? .json("{}", status: 202) : .fixture("pages-health-check")
            case "PUT /repos/o/r/pages", "DELETE /repos/o/r/pages": .noContent()
            default: .fixture("page", status: request.httpMethod == "POST" ? 201 : 200)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.pagesSite("o", "r")
        _ = try await repos.createPagesSite(from: PagesSource(branch: "main", path: "/docs"), in: "o", "r")
        _ = try await repos.createPagesSite(in: "o", "r")
        try await repos.updatePagesSite("o", "r", PagesSiteUpdate(customDomain: .set("docs.example.com"), httpsEnforced: true))
        try await repos.updatePagesSite("o", "r", PagesSiteUpdate(customDomain: .remove))
        try await repos.deletePagesSite("o", "r")
        #expect(try await repos.pagesHealthCheck("o", "r") == nil)
        #expect(try await repos.pagesHealthCheck("o", "r")?.domain?.host == "example.com")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/pages", "POST /repos/o/r/pages", "POST /repos/o/r/pages", "PUT /repos/o/r/pages", "PUT /repos/o/r/pages",
                "DELETE /repos/o/r/pages", "GET /repos/o/r/pages/health", "GET /repos/o/r/pages/health",
            ])
        #expect(transport.requests[1].jsonBody == ["build_type": "legacy", "source": ["branch": "main", "path": "/docs"]])
        #expect(transport.requests[2].jsonBody == ["build_type": "workflow"])
        #expect(transport.requests[3].jsonBody == ["cname": "docs.example.com", "https_enforced": true])
        #expect(transport.requests[4].jsonBody == ["cname": nil])
    }

    @Test func buildAndDeploymentRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/pages/builds": .fixture("page-build-items")
            case "POST /repos/o/r/pages/builds": .fixture("page-build-status", status: 201)
            case "POST /repos/o/r/pages/deployments": .fixture("page-deployment")
            case "GET /repos/o/r/pages/deployments/abc": .fixture("pages-deployment-status")
            case "POST /repos/o/r/pages/deployments/abc/cancel": .noContent()
            default: .fixture("page-build")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.pagesBuilds("o", "r").collect()
        _ = try await repos.latestPagesBuild("o", "r")
        _ = try await repos.pagesBuild(id: 5, in: "o", "r")
        _ = try await repos.requestPagesBuild("o", "r")
        _ = try await repos.createPagesDeployment(NewPagesDeployment(artifactID: 7, buildVersion: "abc123", oidcToken: "jwt"), in: "o", "r")
        let state = try await repos.pagesDeploymentState(id: "abc", in: "o", "r")
        try await repos.cancelPagesDeployment(id: "abc", in: "o", "r")

        #expect(state == .succeeded)
        #expect(state.isFinished)
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/pages/builds", "GET /repos/o/r/pages/builds/latest", "GET /repos/o/r/pages/builds/5",
                "POST /repos/o/r/pages/builds", "POST /repos/o/r/pages/deployments", "GET /repos/o/r/pages/deployments/abc",
                "POST /repos/o/r/pages/deployments/abc/cancel",
            ])
        #expect(transport.requests[4].jsonBody == ["artifact_id": 7, "pages_build_version": "abc123", "oidc_token": "jwt"])
    }
}
