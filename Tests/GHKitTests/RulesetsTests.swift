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

@Suite("Rulesets")
struct RulesetsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func rulesetsDecode() throws {
        let org = try decoder.decode(Ruleset.self, from: loadFixture("org-ruleset"))
        #expect(org.enforcement == .active)
        #expect(org.target == .branch)
        #expect(org.bypassActors == [.team(234)])
        #expect(org.conditions?.refName?.exclude == ["refs/heads/dev*"])
        #expect(org.conditions?.repositoryName?.isProtected == true)
        #expect(org.rules == [.commitAuthorEmailPattern(PatternRule(.contains, "github"))])
        #expect(org.htmlURL?.absoluteString == "https://github.com/organizations/my-org/settings/rules/21")

        let repo = try decoder.decode(Ruleset.self, from: loadFixture("repository-ruleset"))
        #expect(repo.source == "monalisa/my-repo")
        _ = try decoder.decode([Ruleset].self, from: loadFixture("org-ruleset-items"))
        let items = try decoder.decode([Ruleset].self, from: loadFixture("repository-ruleset-items"))
        #expect(items.first?.rules == nil)

        let history = try decoder.decode([RulesetVersion].self, from: loadFixture("ruleset-history"))
        #expect(history.map(\.id) == [3, 2, 1])
        let version = try decoder.decode(RulesetVersion.self, from: loadFixture("org-ruleset-version-with-state"))
        #expect(version.state?.id == 21)
        _ = try decoder.decode(RulesetVersion.self, from: loadFixture("repository-ruleset-version-with-state"))

        let applied = try decoder.decode([AppliedRule].self, from: loadFixture("repository-rule-items"))
        #expect(applied.first?.rule == .commitMessagePattern(PatternRule(.startsWith, "issue")))
        #expect(applied.first?.rulesetID == 42)
        #expect(applied.last?.rulesetSourceType == "Organization")

        let suite = try decoder.decode(RuleSuite.self, from: loadFixture("rule-suite"))
        #expect(suite.result == "bypass")
        #expect(suite.ruleEvaluations?[1].details == "Changes must be made through a pull request.")
        _ = try decoder.decode([RuleSuite].self, from: loadFixture("rule-suite-items"))
    }

    @Test func repositoryIDConditionsAreFlattened() throws {
        let json = #"{"ref_name":{"include":["~DEFAULT_BRANCH"]},"repository_id":{"repository_ids":[1,2]}}"#
        let conditions = try decoder.decode(RulesetConditions.self, from: Data(json.utf8))
        #expect(conditions.repositoryIDs == [1, 2])
        #expect(conditions.refName?.exclude == [])
        let encoded = try decoder.decode(JSONValue.self, from: GitHubJSON.encoder().encode(conditions))
        #expect(encoded == ["ref_name": ["include": ["~DEFAULT_BRANCH"], "exclude": []], "repository_id": ["repository_ids": [1, 2]]])
    }

    @Test(arguments: [
        RepositoryRule.creation, .update(allowsFetchAndMerge: true), .deletion, .requiredLinearHistory, .requiredSignatures,
        .nonFastForward, .requiredDeployments(environments: ["staging"]),
        .pullRequest(
            PullRequestRule(
                requiredApprovingReviewCount: 2, requiredReviewThreadResolution: true, allowedMergeMethods: ["squash"],
                dismissalRestriction: .init(allowedActors: [.init(id: 1, type: "Team")]),
                requiredReviewers: [.init(teamID: 7, filePatterns: ["docs/**"])])),
        .requiredStatusChecks(StatusChecksRule([.init("ci", integrationID: 15368)], strict: true)),
        .mergeQueue(MergeQueueRule()), .commitMessagePattern(PatternRule(.regex, "^(feat|fix):", negate: false, name: "Conventional")),
        .commitAuthorEmailPattern(PatternRule(.endsWith, "@acme.com")), .committerEmailPattern(PatternRule(.contains, "acme")),
        .branchNamePattern(PatternRule(.startsWith, "feat/")), .tagNamePattern(PatternRule(.regex, "^v\\d")),
        .workflows(WorkflowsRule([.init(path: ".github/workflows/ci.yml", repositoryID: 1, ref: "main")])),
        .codeScanning(tools: [CodeScanningTool("CodeQL")]), .codeQuality(severity: "errors"),
        .codeCoverage(CodeCoverageRule(minimumCoverage: 80)), .copilotCodeReview(CopilotReviewRule(reviewOnPush: true)),
        .licenseComplianceScanning, .filePathRestriction(restricted: ["secrets/**"], ignored: ["secrets/README.md"]),
        .maxFilePathLength(200), .fileExtensionRestriction(["*.exe"]), .maxFileSize(megabytes: 10),
        .other(type: "future_rule", parameters: ["level": 3]),
    ])
    func everyRuleRoundTrips(rule: RepositoryRule) throws {
        let data = try GitHubJSON.encoder().encode(rule)
        #expect(try decoder.decode(RepositoryRule.self, from: data) == rule)
        #expect(try decoder.decode(JSONValue.self, from: data)["type"] == .string(rule.type))
    }

    @Test func ruleParametersUseGitHubNames() throws {
        let rule = RepositoryRule.requiredStatusChecks(StatusChecksRule([.init("ci", integrationID: 1)], strict: true))
        let json = try decoder.decode(JSONValue.self, from: GitHubJSON.encoder().encode(rule))
        #expect(
            json == [
                "type": "required_status_checks",
                "parameters": [
                    "required_status_checks": [["context": "ci", "integration_id": 1]], "strict_required_status_checks_policy": true,
                ],
            ])
        let deletion = try decoder.decode(JSONValue.self, from: GitHubJSON.encoder().encode(RepositoryRule.deletion))
        #expect(deletion == ["type": "deletion"])
    }

    // MARK: Requests

    @Test func repositoryRulesetRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/rulesets": .fixture("repository-ruleset-items")
            case "DELETE /repos/o/r/rulesets/42": .noContent()
            case "GET /repos/o/r/rulesets/42/history": .fixture("ruleset-history")
            case "GET /repos/o/r/rulesets/42/history/3": .fixture("repository-ruleset-version-with-state")
            case "GET /repos/o/r/rules/branches/release%2Fv1": .fixture("repository-rule-items")
            default: .fixture("repository-ruleset", status: request.httpMethod == "POST" ? 201 : 200)
            }
        }
        let client = makeClient(transport)
        let rulesets = client.rulesets(.repository("o", "r"))
        _ = try await rulesets.list(targets: [.branch, .tag]).collect()
        _ = try await rulesets.ruleset(id: 42, includesParents: false)
        _ = try await rulesets.create(
            NewRuleset(
                name: "main", bypassActors: [.organizationAdmins()],
                conditions: RulesetConditions(refName: .init(include: ["~DEFAULT_BRANCH"])),
                rules: [.deletion, .nonFastForward]))
        _ = try await rulesets.update(id: 42, RulesetUpdate(enforcement: .disabled))
        try await rulesets.delete(id: 42)
        _ = try await rulesets.history(of: 42).collect()
        _ = try await rulesets.version(3, of: 42)
        _ = try await client.repositories.rules(for: "release/v1", in: "o", "r").collect()

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/rulesets", "GET /repos/o/r/rulesets/42", "POST /repos/o/r/rulesets", "PUT /repos/o/r/rulesets/42",
                "DELETE /repos/o/r/rulesets/42", "GET /repos/o/r/rulesets/42/history", "GET /repos/o/r/rulesets/42/history/3",
                "GET /repos/o/r/rules/branches/release%2Fv1",
            ])
        #expect(transport.requests[0].queryItems == ["targets": "branch,tag", "includes_parents": "true", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["includes_parents": "false"])
        // The branch is one path segment, so its slash is escaped.
        #expect(transport.requests[7].url?.path(percentEncoded: true) == "/repos/o/r/rules/branches/release%2Fv1")
        #expect(
            transport.requests[2].jsonBody == [
                "name": "main", "enforcement": "active",
                "bypass_actors": [["actor_type": "OrganizationAdmin", "bypass_mode": "always"]],
                "conditions": ["ref_name": ["include": ["~DEFAULT_BRANCH"], "exclude": []]],
                "rules": [["type": "deletion"], ["type": "non_fast_forward"]],
            ])
        #expect(transport.requests[3].jsonBody == ["enforcement": "disabled"])
    }

    @Test func organizationRequestsSkipRepositoryOnlyParameters() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/orgs/acme/rulesets": .fixture("org-ruleset-items")
            case "/orgs/acme/rulesets/21": .fixture("org-ruleset")
            case "/orgs/acme/rulesets/rule-suites": .fixture("rule-suite-items")
            default: .fixture("rule-suite")
            }
        }
        let acme = makeClient(transport).rulesets(.organization("acme"))
        _ = try await acme.list().collect()
        _ = try await acme.ruleset(id: 21)
        _ = try await acme.ruleSuites(ref: "refs/heads/main", repository: "app", period: .week, actor: "mona", result: .fail).collect()
        _ = try await acme.ruleSuite(id: 9, includeMetadata: true)
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[1].queryItems == [:])
        #expect(
            transport.requests[2].queryItems == [
                "ref": "refs/heads/main", "repository_name": "app", "time_period": "week", "actor_name": "mona",
                "rule_suite_result": "fail", "evaluate_status": "all", "per_page": "100",
            ])
        #expect(transport.requests[3].path == "/orgs/acme/rulesets/rule-suites/9")
        #expect(transport.requests[3].queryItems == ["include_metadata": "true"])
    }

    @Test func repositoryRuleSuitesDropTheRepositoryFilter() async throws {
        let transport = MockTransport(.fixture("rule-suite-items"))
        _ = try await makeClient(transport).rulesets(.repository("o", "r")).ruleSuites(repository: "ignored").collect()
        #expect(transport.requests[0].path == "/repos/o/r/rulesets/rule-suites")
        #expect(transport.requests[0].queryItems["repository_name"] == nil)
    }
}
