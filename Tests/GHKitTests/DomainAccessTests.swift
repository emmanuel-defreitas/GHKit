import Foundation
import Testing

@testable import GHKitCore
@testable import GHKitIssues
@testable import GHKitOrganizations
@testable import GHKitProjects
@testable import GHKitPullRequests
@testable import GHKitRepositories
@testable import GHKitUsers

@Suite("Domain access")
struct DomainAccessTests {
    @Test func combinesDomainsAtTheHigherLevel() {
        let access = [GitHubDomain.issues, .pullRequests].access(.write)
        #expect(access.scopes == [.repo])
        #expect(
            access.permissions.map(\.description) == [
                "contents=write", "issues=write", "metadata=read", "pull_requests=write",
            ])
        // Reading keeps the read levels.
        #expect([GitHubDomain.issues].access(.read).permissions.map(\.description) == ["issues=read", "metadata=read"])
    }

    @Test func writeIncludesReadAndDropsCoveredScopes() {
        #expect(GitHubDomain.projects.access(.read).scopeList == [.readOrg, .readProject])
        #expect(GitHubDomain.projects.access(.write).scopeList == [.project, .readOrg])
        #expect(GitHubDomain.rulesets.access(.write).scopeList == [.adminOrg, .repo])
        #expect(GitHubDomain.organizations == GitHubDomain("organizations"))
    }

    @Test func broaderScopesCoverNarrowerOnes() {
        let access = GitHubAccess(scopes: [.readOrg, .readProject, .publicRepo])
        #expect(access.missingScopes(granted: [.adminOrg, .project, .repo]).isEmpty)
        #expect(access.missingScopes(granted: [.writeOrg]) == [.readProject, .publicRepo])
    }

    @Test func tokenLinksPrefillTheForm() throws {
        let access = [GitHubDomain.issues].access(.write)
        let fine = access.fineGrainedTokenURL(name: "My App", description: "Triage", owner: "acme")
        #expect(
            fine.absoluteString
                == "https://github.com/settings/personal-access-tokens/new?name=My%20App&description=Triage&target_name=acme&issues=write&metadata=read"
        )
        let classic = [GitHubDomain.projects].access(.write).classicTokenURL(description: "My App")
        #expect(classic.absoluteString == "https://github.com/settings/tokens/new?scopes=project,read:org&description=My%20App")
        let enterprise = access.classicTokenURL(description: "x", server: .enterpriseServer(URL(string: "https://ghe.example.com")!))
        #expect(enterprise.host() == "ghe.example.com")
    }

    @Test func parsesAcceptedPermissions() {
        let sets = GitHubPermission.parseAlternatives("repository_projects=write; organization_projects=admin, members=read")
        #expect(sets.map { $0.map(\.description) } == [["repository_projects=write"], ["organization_projects=admin", "members=read"]])
        #expect(GitHubPermission("issues") == nil)
        #expect(GitHubPermission("issues=owner") == nil)
    }

    @Test func forbiddenErrorsSayWhatsMissing() async {
        let transport = MockTransport(
            .json(
                #"{"message":"Resource not accessible by personal access token"}"#, status: 403,
                headers: ["X-Accepted-GitHub-Permissions": "issues=write"]))
        do {
            _ = try await makeClient(transport).issues.issue(1, in: "acme", "app")
            Issue.record("Expected an error")
        } catch {
            let missing = error.missingAccess
            #expect(missing?.acceptedPermissions == [[GitHubPermission("issues", .write)]])
            #expect(missing?.description == "needs permissions issues=write")
        }
    }

    @Test func notFoundWithAnAcceptedScopeIsJustMissing() {
        let covered = ResponseMetadata(statusCode: 404, headers: ["x-accepted-oauth-scopes": "repo", "x-oauth-scopes": "repo, gist"])
        #expect(GitHubError.notFound(nil, covered).missingAccess == nil)

        let lacking = ResponseMetadata(statusCode: 404, headers: ["x-accepted-oauth-scopes": "repo", "x-oauth-scopes": "gist"])
        let missing = GitHubError.notFound(nil, lacking).missingAccess
        #expect(missing?.acceptedScopes == [.repo])
        #expect(missing?.description == "needs one of the scopes repo; token has gist")

        #expect(GitHubError.forbidden(nil, ResponseMetadata(statusCode: 403, headers: [:])).missingAccess == nil)
    }

    @Test func checksClassicScopesForADomain() async throws {
        let transport = MockTransport { request, _ in
            let token = request.value(forHTTPHeaderField: "Authorization")
            let scopes = token == "Bearer org" ? "admin:org, repo" : token == "Bearer fine" ? "" : "repo"
            return .fixture("rate-limit-overview", headers: ["X-OAuth-Scopes": scopes])
        }
        let github = makeClient(
            transport, authenticator: .routed(default: .token("main"), domains: [.organizations: .token("org"), .users: .token("fine")]))
        #expect(try await github.missingScopes(for: .projects, .write) == [.project, .readOrg])
        #expect(try await github.missingScopes(for: .organizations, .write) == [.adminOrgHook])
        #expect(try await github.missingScopes(for: .issues, .write) == [])
        // Tokens that list no scopes can't be checked ahead of time.
        #expect(try await github.missingScopes(for: .users) == nil)
        #expect(transport.requests.allSatisfy { $0.path == "/rate_limit" })
    }
}
