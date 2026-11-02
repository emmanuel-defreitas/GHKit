import Foundation
import Testing

@testable import GHKit

@Suite("Branches")
struct BranchesTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func branchesDecode() throws {
        let branches = try decoder.decode([Branch].self, from: loadFixture("short-branch-with-protection-items"))
        #expect(branches.first?.isProtected == true)
        #expect(branches.first?.protection?.requiredStatusChecks?.contexts == ["ci-test", "linter"])
        #expect(branches.first?.protection?.requiredStatusChecks?.checks.isEmpty == true)
        _ = try decoder.decode([Branch].self, from: loadFixture("branch-short-items"))

        let main = try decoder.decode(BranchDetails.self, from: loadFixture("branch-get"))
        #expect(main.name == "main")
        #expect(main.commit.commit.commentCount == 77)
        #expect(main.commit.author?.login == "octocat")
        #expect(main.htmlURL != nil)
        _ = try decoder.decode(BranchDetails.self, from: loadFixture("branch-with-protection"))

        let commit = try decoder.decode(Commit.self, from: loadFixture("commit"))
        #expect(commit.stats?.total == 108)
        #expect(commit.files?.first?.status == .modified)
    }

    @Test func commitAuthorMayBeAnEmptyObject() throws {
        let json = #"{"sha":"1","commit":{"message":"m"},"author":{},"committer":null,"parents":[]}"#
        let commit = try decoder.decode(Commit.self, from: Data(json.utf8))
        #expect(commit.author == nil)
        #expect(commit.committer == nil)
    }

    @Test func protectionDecodes() throws {
        let protection = try decoder.decode(BranchProtection.self, from: loadFixture("branch-protection"))
        #expect(protection.enforceAdmins == true)
        #expect(protection.requiredPullRequestReviews?.dismissalRestrictions?.teams.first?.slug == "justice-league")
        #expect(protection.restrictions?.apps.first?.slug == "octoapp")
        // The app's owner arrives without a `type`, so it's dropped rather than failing the whole response.
        #expect(protection.restrictions?.apps.first?.owner == nil)

        let updated = try decoder.decode(BranchProtection.self, from: loadFixture("branch-protection-update"))
        #expect(updated.url != nil)

        let reviews = try decoder.decode(ReviewProtection.self, from: loadFixture("protected-branch-pull-request-review"))
        #expect(reviews.requiredApprovingReviewCount == 2)
        let checks = try decoder.decode(StatusCheckPolicy.self, from: loadFixture("status-check-policy"))
        #expect(checks.strict == true)
        let restrictions = try decoder.decode(BranchRestrictions.self, from: loadFixture("branch-restriction-policy"))
        #expect(restrictions.users.first?.login == "octocat")
        _ = try decoder.decode([GitHubApp].self, from: loadFixture("integration-items"))
    }

    @Test func protectionTogglesRoundTrip() throws {
        var protection = BranchProtection()
        protection.allowForcePushes = false
        protection.lockBranch = true
        let data = try GitHubJSON.encoder().encode(protection)
        let json = try decoder.decode(JSONValue.self, from: data)
        #expect(json == ["allow_force_pushes": ["enabled": false], "lock_branch": ["enabled": true]])
        #expect(try decoder.decode(BranchProtection.self, from: data) == protection)
    }

    // MARK: Requests

    @Test func branchRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/branches": .fixture("short-branch-with-protection-items")
            case "GET /repos/o/r/branches/release/v1": .fixture("branch-get")
            case "POST /repos/o/r/branches/old/rename": .fixture("branch-with-protection", status: 201)
            case "GET /repos/o/r/commits/abc/branches-where-head": .fixture("branch-short-items")
            default: .json(#"{"message":"Not Found"}"#, status: 404)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.branches("o", "r", protected: true).collect()
        _ = try await repos.branch("release/v1", in: "o", "r")
        _ = try await repos.renameBranch("old", to: "new", in: "o", "r")
        _ = try await repos.branches(withHead: "abc", in: "o", "r")
        #expect(transport.requests[0].queryItems == ["protected": "true", "per_page": "100"])
        #expect(transport.requests[2].jsonBody == ["new_name": "new"])
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/branches", "GET /repos/o/r/branches/release/v1", "POST /repos/o/r/branches/old/rename",
                "GET /repos/o/r/commits/abc/branches-where-head",
            ])
    }

    @Test func mergeReturnsNilWhenNothingToMerge() async throws {
        let transport = MockTransport(.fixture("commit", status: 201), .noContent())
        let repos = makeClient(transport).repositories
        let merged = try await repos.merge("feature", into: "main", in: "o", "r", message: "Ship it")
        let nothing = try await repos.merge("feature", into: "main", in: "o", "r")
        #expect(merged?.sha == "6dcb09b5b57875f334f61aebed695e2e4193db5e")
        #expect(nothing == nil)
        #expect(transport.requests[0].route == "POST /repos/o/r/merges")
        #expect(transport.requests[0].jsonBody == ["base": "main", "head": "feature", "commit_message": "Ship it"])
        #expect(transport.requests[1].jsonBody == ["base": "main", "head": "feature"])
    }

    @Test func protectSendsEveryRequiredRule() async throws {
        let transport = MockTransport(.fixture("branch-protection-update"))
        let rules = BranchProtectionRules(
            requiredStatusChecks: RequiredStatusChecks(strict: true, checks: [StatusCheck("ci/build", appID: StatusCheck.anyApp)]),
            requiredPullRequestReviews: RequiredReviews(
                requiredApprovingReviewCount: 2, dismissStaleReviews: true,
                bypassPullRequestAllowances: PushAllowances(users: ["mona"])),
            enforceAdmins: true, allowForcePushes: false)
        _ = try await makeClient(transport).repositories.protect("main", in: "o", "r", rules: rules)
        _ = try await makeClient(transport).repositories.protect("main", in: "o", "r", rules: BranchProtectionRules())
        #expect(transport.requests[0].route == "PUT /repos/o/r/branches/main/protection")
        #expect(
            transport.requests[0].jsonBody == [
                "required_status_checks": ["strict": true, "checks": [["context": "ci/build", "app_id": -1]]],
                "required_pull_request_reviews": [
                    "required_approving_review_count": 2, "dismiss_stale_reviews": true,
                    "bypass_pull_request_allowances": ["users": ["mona"], "teams": [], "apps": []],
                ],
                "restrictions": nil, "enforce_admins": true, "allow_force_pushes": false,
            ])
        #expect(
            transport.requests[1].jsonBody == [
                "required_status_checks": nil, "required_pull_request_reviews": nil, "restrictions": nil, "enforce_admins": false,
            ])
    }

    @Test func protectionRuleRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/branches/main/protection": .fixture("branch-protection")
            case "GET /repos/o/r/branches/main/protection/enforce_admins": .fixture("protected-branch-admin-enforced")
            case "GET /repos/o/r/branches/main/protection/required_signatures": .json(#"{"url":"https://x","enabled":false}"#)
            case "GET /repos/o/r/branches/main/protection/required_pull_request_reviews",
                "PATCH /repos/o/r/branches/main/protection/required_pull_request_reviews":
                .fixture("protected-branch-pull-request-review")
            case "GET /repos/o/r/branches/main/protection/required_status_checks",
                "PATCH /repos/o/r/branches/main/protection/required_status_checks":
                .fixture("status-check-policy")
            case "GET /repos/o/r/branches/main/protection/restrictions": .fixture("branch-restriction-policy")
            default: .noContent()
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.protection(of: "main", in: "o", "r")
        try await repos.removeProtection(from: "main", in: "o", "r")
        #expect(try await repos.adminEnforcement(of: "main", in: "o", "r"))
        try await repos.setAdminEnforcement(true, on: "main", in: "o", "r")
        try await repos.setAdminEnforcement(false, on: "main", in: "o", "r")
        #expect(try await repos.signatureRequirement(of: "main", in: "o", "r") == false)
        try await repos.setSignatureRequirement(true, on: "main", in: "o", "r")
        try await repos.setSignatureRequirement(false, on: "main", in: "o", "r")
        _ = try await repos.reviewProtection(of: "main", in: "o", "r")
        _ = try await repos.updateReviewProtection(
            RequiredReviews(requiredApprovingReviewCount: nil, requireCodeOwnerReviews: true), on: "main", in: "o", "r")
        try await repos.removeReviewProtection(from: "main", in: "o", "r")
        _ = try await repos.statusChecks(of: "main", in: "o", "r")
        _ = try await repos.updateStatusChecks(on: "main", in: "o", "r", strict: false)
        try await repos.removeStatusChecks(from: "main", in: "o", "r")
        _ = try await repos.pushRestrictions(of: "main", in: "o", "r")
        try await repos.removePushRestrictions(from: "main", in: "o", "r")

        let base = "/repos/o/r/branches/main/protection"
        #expect(
            transport.requests.map(\.route) == [
                "GET \(base)", "DELETE \(base)",
                "GET \(base)/enforce_admins", "POST \(base)/enforce_admins", "DELETE \(base)/enforce_admins",
                "GET \(base)/required_signatures", "POST \(base)/required_signatures", "DELETE \(base)/required_signatures",
                "GET \(base)/required_pull_request_reviews", "PATCH \(base)/required_pull_request_reviews",
                "DELETE \(base)/required_pull_request_reviews",
                "GET \(base)/required_status_checks", "PATCH \(base)/required_status_checks", "DELETE \(base)/required_status_checks",
                "GET \(base)/restrictions", "DELETE \(base)/restrictions",
            ])
        #expect(transport.requests[9].jsonBody == ["require_code_owner_reviews": true])
        #expect(transport.requests[12].jsonBody == ["strict": false])
    }

    @Test func statusCheckContextRequests() async throws {
        let transport = MockTransport(.json(#"["ci/build"]"#))
        let repos = makeClient(transport).repositories
        #expect(try await repos.statusCheckContexts(of: "main", in: "o", "r") == ["ci/build"])
        _ = try await repos.addStatusCheckContexts(["lint"], to: "main", in: "o", "r")
        _ = try await repos.setStatusCheckContexts(["ci/build"], on: "main", in: "o", "r")
        _ = try await repos.removeStatusCheckContexts(["lint"], from: "main", in: "o", "r")
        let path = "/repos/o/r/branches/main/protection/required_status_checks/contexts"
        #expect(transport.requests.map(\.route) == ["GET \(path)", "POST \(path)", "PUT \(path)", "DELETE \(path)"])
        #expect(transport.requests[1].jsonBody == ["contexts": ["lint"]])
        #expect(transport.requests[3].jsonBody == ["contexts": ["lint"]])
    }

    @Test func pushAccessRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case let path where path.hasSuffix("/users"): .fixture("simple-user-items")
            case let path where path.hasSuffix("/teams"): .fixture("team-items")
            default: .fixture("integration-items")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.usersWithPushAccess(to: "main", in: "o", "r")
        _ = try await repos.teamsWithPushAccess(to: "main", in: "o", "r")
        _ = try await repos.appsWithPushAccess(to: "main", in: "o", "r")
        _ = try await repos.addPushAccess(users: ["mona"], to: "main", in: "o", "r")
        _ = try await repos.addPushAccess(teams: ["core"], to: "main", in: "o", "r")
        _ = try await repos.addPushAccess(apps: ["bot"], to: "main", in: "o", "r")
        _ = try await repos.setPushAccess(users: ["mona"], on: "main", in: "o", "r")
        _ = try await repos.setPushAccess(teams: ["core"], on: "main", in: "o", "r")
        _ = try await repos.setPushAccess(apps: ["bot"], on: "main", in: "o", "r")
        _ = try await repos.removePushAccess(users: ["mona"], from: "main", in: "o", "r")
        _ = try await repos.removePushAccess(teams: ["core"], from: "main", in: "o", "r")
        _ = try await repos.removePushAccess(apps: ["bot"], from: "main", in: "o", "r")
        let base = "/repos/o/r/branches/main/protection/restrictions"
        #expect(
            transport.requests.map(\.route)
                == ["GET", "POST", "PUT", "DELETE"].flatMap { method in
                    ["users", "teams", "apps"].map { "\(method) \(base)/\($0)" }
                })
        #expect(transport.requests[0].jsonBody == nil)
        #expect(transport.requests[3].jsonBody == ["users": ["mona"]])
        #expect(transport.requests[7].jsonBody == ["teams": ["core"]])
        #expect(transport.requests[11].jsonBody == ["apps": ["bot"]])
    }
}
