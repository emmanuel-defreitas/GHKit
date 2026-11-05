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

@Suite("Repositories")
struct RepositoriesTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func repositoryDecodesEveryShape() throws {
        let full = try decoder.decode(Repository.self, from: loadFixture("full-repository"))
        #expect(full.fullName == "octocat/Hello-World")
        #expect(full.license?.spdxID == "MIT")
        #expect(full.allowRebaseMerge == true)
        #expect(full.subscribersCount == 42)
        #expect(full.parent?.fullName == "octocat/Hello-World")
        #expect(full.source != nil)

        _ = try decoder.decode(Repository.self, from: loadFixture("full-repository-default"))

        _ = try decoder.decode([Repository].self, from: loadFixture("repository-items"))
        _ = try decoder.decode([Repository].self, from: loadFixture("public-repository-items"))
        _ = try decoder.decode(Repository.self, from: loadFixture("minimal-repository"))
    }

    @Test func detailModelsDecode() throws {
        let contributors = try decoder.decode([Contributor].self, from: loadFixture("contributor-items"))
        #expect(contributors.first?.contributions == 32)
        let tags = try decoder.decode([RepositoryTag].self, from: loadFixture("tag-items"))
        #expect(tags.first?.commit.sha.isEmpty == false)
        let activity = try decoder.decode([RepositoryActivity].self, from: loadFixture("activity-items"))
        #expect(activity.first?.timestamp != nil)
        #expect(activity.first?.actor?.login == "octocat")
        let profile = try decoder.decode(CommunityProfile.self, from: loadFixture("community-profile"))
        #expect(profile.healthPercentage == 100)
        #expect(profile.files.contributing?.htmlURL != nil)
        #expect(profile.files.license?.key == "mit")
    }

    @Test func securityAndAnalysisSkipsNonStatusEntries() throws {
        let json = #"""
            {"advanced_security":{"status":"enabled"},"secret_scanning":{"status":"disabled"},
             "secret_scanning_delegated_bypass_options":{"reviewers":[]}}
            """#
        let security = try decoder.decode(SecurityAndAnalysis.self, from: Data(json.utf8))
        #expect(security[.advancedSecurity] == true)
        #expect(security[.secretScanning] == false)
        #expect(security.features.count == 2)
    }

    @Test func activityDecodesCurrentFieldNames() throws {
        let json = #"""
            {"id":1,"before":"a","after":"b","ref":"refs/heads/main","timestamp":"2024-01-01T00:00:00Z",
             "activity_type":"force_push","actor":{"id":1,"login":"mona","node_id":"U1","type":"User"}}
            """#
        let activity = try decoder.decode(RepositoryActivity.self, from: Data(json.utf8))
        #expect(activity.activityType == .forcePush)
        #expect(activity.actor?.login == "mona")
        #expect(activity.timestamp != nil)
    }

    // MARK: Requests

    @Test func fetchOneRepository() async throws {
        let transport = MockTransport(.fixture("full-repository"))
        let repository = try await makeClient(transport).repositories.repository("octocat", "Hello-World")
        #expect(repository.fullName == "octocat/Hello-World")
        #expect(repository.license?.spdxID == "MIT")
        #expect(repository.parent?.fullName == "octocat/Hello-World")
        #expect(transport.requests.map(\.route) == ["GET /repos/octocat/Hello-World"])
    }

    @Test func createSendsVisibilityAndMergeSettings() async throws {
        let transport = MockTransport(.fixture("full-repository", status: 201))
        let repos = makeClient(transport).repositories
        let new = NewRepository(
            name: "rockets", visibility: .private, autoInitialize: true, licenseTemplate: "mit",
            merge: MergeSettings(allowMergeCommit: false, squashMergeCommitTitle: .pullRequestTitle),
            customProperties: ["tier": "gold"])
        _ = try await repos.create(new)
        _ = try await repos.create(new, in: "acme")
        #expect(transport.requests.map(\.path) == ["/user/repos", "/orgs/acme/repos"])
        #expect(
            transport.requests[0].jsonBody == [
                "name": "rockets", "visibility": "private", "private": true, "auto_init": true, "license_template": "mit",
                "allow_merge_commit": false, "squash_merge_commit_title": "PR_TITLE", "custom_properties": ["tier": "gold"],
            ])
    }

    @Test func updateSendsSecurityFeatures() async throws {
        let transport = MockTransport(.fixture("full-repository"))
        _ = try await makeClient(transport).repositories.update(
            "octocat", "Hello-World",
            RepositoryUpdate(
                defaultBranch: "main", archived: true, merge: MergeSettings(deleteBranchOnMerge: true),
                securityFeatures: [.secretScanning: true]))
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "PATCH")
        #expect(request.path == "/repos/octocat/Hello-World")
        #expect(
            request.jsonBody == [
                "default_branch": "main", "archived": true, "delete_branch_on_merge": true,
                "security_and_analysis": ["secret_scanning": ["status": "enabled"]],
            ])
    }

    @Test func listQueries() async throws {
        let transport = MockTransport(.json("[]"))
        let repos = makeClient(transport).repositories
        _ = try await repos.list(matching: RepositoryFilter(visibility: .public, affiliation: [.owner, .organizationMember])).collect()
        _ = try await repos.list(of: "octocat", type: .member, sort: .pushed, ascending: true).collect()
        _ = try await repos.list(in: "acme", type: .sources).collect()
        _ = try await repos.all(since: 99).collect()
        #expect(transport.requests.map(\.path) == ["/user/repos", "/users/octocat/repos", "/orgs/acme/repos", "/repositories"])
        #expect(
            transport.requests[0].queryItems == [
                "visibility": "public", "affiliation": "owner,organization_member", "sort": "full_name", "per_page": "100",
            ])
        #expect(transport.requests[1].queryItems == ["type": "member", "sort": "pushed", "direction": "asc", "per_page": "100"])
        #expect(transport.requests[2].queryItems == ["type": "sources", "sort": "created", "per_page": "100"])
        #expect(transport.requests[3].queryItems == ["since": "99"])
    }

    @Test func transferAndDelete() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("minimal-repository", status: 202)
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.transfer("octocat", "Hello-World", to: "acme", newName: "hello", teamIDs: [12])
        try await repos.delete("octocat", "Hello-World")
        #expect(transport.requests[0].path == "/repos/octocat/Hello-World/transfer")
        #expect(transport.requests[0].jsonBody == ["new_owner": "acme", "new_name": "hello", "team_ids": [12]])
        #expect(transport.requests[1].httpMethod == "DELETE")
    }

    @Test func details() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/repos/o/r/topics": .fixture("topic")
            case "/repos/o/r/languages": .fixture("language")
            case "/repos/o/r/tags": .fixture("tag-items")
            case "/repos/o/r/teams": .fixture("team-items")
            case "/repos/o/r/activity": .fixture("activity-items")
            case "/repos/o/r/community/profile": .fixture("community-profile")
            case "/repos/o/r/hash-algorithm": .json(#"{"hash_algorithm":"sha256"}"#)
            default: .noContent()
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.topics("o", "r") == ["octocat", "atom", "electron", "api"])
        _ = try await repos.replaceTopics(["swift"], on: "o", "r")
        #expect(try await repos.languages("o", "r")["C"] == 78769)
        _ = try await repos.tags("o", "r").collect()
        _ = try await repos.teams("o", "r").collect()
        _ = try await repos.activity("o", "r", matching: RepositoryActivityFilter(ref: "main", type: .push)).collect()
        _ = try await repos.communityProfile("o", "r")
        #expect(try await repos.hashAlgorithm("o", "r") == .sha256)
        #expect(transport.requests[1].httpMethod == "PUT")
        #expect(transport.requests[1].jsonBody == ["names": ["swift"]])
        #expect(
            transport.requests[5].queryItems == [
                "ref": "main", "activity_type": "push", "direction": "desc", "per_page": "100",
            ])
    }

    @Test func contributorsHandleEmptyRepositories() async throws {
        let transport = MockTransport(.noContent())
        let contributors = try await makeClient(transport).repositories.contributors("o", "r", includeAnonymous: true).collect()
        #expect(contributors.isEmpty)
        #expect(transport.requests.first?.queryItems == ["anon": "1", "per_page": "100"])
    }
}
