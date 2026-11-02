import Foundation
import Testing

@testable import GHKit

@Suite("Deployments")
struct DeploymentsTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let deployment = try decoder.decode(Deployment.self, from: loadFixture("deployment"))
        #expect(deployment.ref == "topic-branch")
        _ = try decoder.decode(Deployment.self, from: loadFixture("deployment-simple-example"))
        _ = try decoder.decode([Deployment].self, from: loadFixture("deployment-items"))
        let status = try decoder.decode(DeploymentStatus.self, from: loadFixture("deployment-status"))
        #expect(status.state == .success)
        _ = try decoder.decode([DeploymentStatus].self, from: loadFixture("deployment-status-items"))

        let environment = try decoder.decode(DeploymentEnvironment.self, from: loadFixture("environment"))
        #expect(environment.deploymentBranchPolicy == .customPatterns)
        #expect(environment.protectionRules?.first?.waitTimer == 30)
        let reviewers = try #require(environment.protectionRules?[1].reviewers)
        guard case .user(let user) = reviewers[0], case .team(let team) = reviewers[1] else {
            Issue.record("Expected a user and a team")
            return
        }
        #expect(user.login == "octocat")
        #expect(team.slug == "justice-league")

        _ = try decoder.decode(DeploymentBranchPattern.self, from: loadFixture("deployment-branch-policy-wildcard"))
        let rule = try decoder.decode(DeploymentProtectionRule.self, from: loadFixture("deployment-protection-rule"))
        #expect(rule.enabled)
    }

    @Test func emptyStatusURLsDecodeAsNil() throws {
        let json = #"""
            {"id":1,"node_id":"n","state":"queued","log_url":"","environment_url":"","target_url":"",
             "url":"https://api.github.com/x","deployment_url":"https://api.github.com/d","repository_url":"https://api.github.com/r",
             "created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}
            """#
        let status = try decoder.decode(DeploymentStatus.self, from: Data(json.utf8))
        #expect(status.logURL == nil)
        #expect(status.environmentURL == nil)
    }

    @Test func deploymentRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/deployments": .fixture("deployment-items")
            case "POST /repos/o/r/deployments":
                request.jsonBody?["ref"] == "behind"
                    ? .json(#"{"message":"Auto-merged main into topic-branch on deployment."}"#, status: 202)
                    : .fixture("deployment", status: 201)
            case "DELETE /repos/o/r/deployments/1": .noContent()
            case "GET /repos/o/r/deployments/1/statuses": .fixture("deployment-status-items")
            case "GET /repos/o/r/deployments/1/statuses/2", "POST /repos/o/r/deployments/1/statuses": .fixture("deployment-status")
            default: .fixture("deployment")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.deployments("o", "r", environment: "production").collect()
        _ = try await repos.deployment(id: 1, in: "o", "r")
        let created = try await repos.createDeployment(
            NewDeployment(ref: "main", environment: "staging", requiredContexts: [], payload: ["region": "eu"]), in: "o", "r")
        let merged = try await repos.createDeployment(NewDeployment(ref: "behind"), in: "o", "r")
        try await repos.deleteDeployment(id: 1, in: "o", "r")
        _ = try await repos.deploymentStatuses(of: 1, in: "o", "r").collect()
        _ = try await repos.deploymentStatus(id: 2, of: 1, in: "o", "r")
        _ = try await repos.createDeploymentStatus(
            NewDeploymentStatus(.success, environmentURL: URL(string: "https://staging.example.com"), autoInactive: false), on: 1, in: "o",
            "r")

        #expect(created?.id == 1)
        #expect(merged == nil)
        #expect(transport.requests[0].queryItems == ["environment": "production", "per_page": "100"])
        #expect(
            transport.requests[2].jsonBody == [
                "ref": "main", "environment": "staging", "required_contexts": [], "payload": ["region": "eu"],
            ])
        #expect(
            transport.requests[7].jsonBody == ["state": "success", "environment_url": "https://staging.example.com", "auto_inactive": false])
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/deployments", "GET /repos/o/r/deployments/1", "POST /repos/o/r/deployments",
                "POST /repos/o/r/deployments", "DELETE /repos/o/r/deployments/1", "GET /repos/o/r/deployments/1/statuses",
                "GET /repos/o/r/deployments/1/statuses/2", "POST /repos/o/r/deployments/1/statuses",
            ])
    }

    @Test func environmentRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/environments": .fixture("environments")
            case "DELETE /repos/o/r/environments/QA%20env": .noContent()
            default: .fixture("environment")
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.environments("o", "r").collect().first?.name == "staging")
        _ = try await repos.environment("staging", in: "o", "r")
        _ = try await repos.setEnvironment(
            "production", in: "o", "r",
            EnvironmentSettings(waitTimer: 10, reviewers: [.team(1), .user(2)], deploymentBranchPolicy: .protectedBranches))
        _ = try await repos.setEnvironment("preview", in: "o", "r", EnvironmentSettings(deploymentBranchPolicy: .allBranches))
        _ = try await repos.setEnvironment("bare", in: "o", "r")
        try await repos.deleteEnvironment("QA env", in: "o", "r")

        #expect(
            transport.requests[2].jsonBody == [
                "wait_timer": 10, "reviewers": [["type": "Team", "id": 1], ["type": "User", "id": 2]],
                "deployment_branch_policy": ["protected_branches": true, "custom_branch_policies": false],
            ])
        #expect(transport.requests[3].jsonBody == ["deployment_branch_policy": nil])
        #expect(transport.requests[4].jsonBody == [:])
        #expect(transport.requests[5].url?.path(percentEncoded: true) == "/repos/o/r/environments/QA%20env")
    }

    @Test func branchPatternAndProtectionRuleRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasSuffix("/deployment-branch-policies") && route.hasPrefix("GET"):
                .fixture("deployment-branch-policies-list")
            case let route where route.hasSuffix("/apps"): .fixture("custom-deployment-protection-rule-apps")
            case "GET /repos/o/r/environments/prod/deployment_protection_rules":
                .json(
                    #"{"total_count":1,"custom_deployment_protection_rules":[\#(String(decoding: loadFixture("deployment-protection-rule"), as: UTF8.self))]}"#)
            case let route where route.contains("deployment_protection_rules"):
                request.httpMethod == "DELETE" ? .noContent() : .fixture("deployment-protection-rule", status: 201)
            default: request.httpMethod == "DELETE" ? .noContent() : .fixture("deployment-branch-policy-wildcard")
            }
        }
        let repos = makeClient(transport).repositories
        #expect(try await repos.deploymentBranchPatterns(for: "prod", in: "o", "r").collect().map(\.name) == ["release/*", "main"])
        _ = try await repos.deploymentBranchPattern(id: 1, for: "prod", in: "o", "r")
        _ = try await repos.addDeploymentBranchPattern("v*", type: .tag, to: "prod", in: "o", "r")
        _ = try await repos.updateDeploymentBranchPattern(id: 1, to: "release/*/*", for: "prod", in: "o", "r")
        try await repos.deleteDeploymentBranchPattern(id: 1, for: "prod", in: "o", "r")
        #expect(try await repos.deploymentProtectionRules(for: "prod", in: "o", "r").collect().count == 1)
        _ = try await repos.deploymentProtectionRule(id: 3, for: "prod", in: "o", "r")
        #expect(try await repos.availableProtectionRuleApps(for: "prod", in: "o", "r").collect().count == 2)
        _ = try await repos.enableProtectionRule(appID: 7, for: "prod", in: "o", "r")
        try await repos.disableProtectionRule(id: 3, for: "prod", in: "o", "r")

        let env = "/repos/o/r/environments/prod"
        #expect(
            transport.requests.map(\.route) == [
                "GET \(env)/deployment-branch-policies", "GET \(env)/deployment-branch-policies/1",
                "POST \(env)/deployment-branch-policies", "PUT \(env)/deployment-branch-policies/1",
                "DELETE \(env)/deployment-branch-policies/1", "GET \(env)/deployment_protection_rules",
                "GET \(env)/deployment_protection_rules/3", "GET \(env)/deployment_protection_rules/apps",
                "POST \(env)/deployment_protection_rules", "DELETE \(env)/deployment_protection_rules/3",
            ])
        #expect(transport.requests[2].jsonBody == ["name": "v*", "type": "tag"])
        #expect(transport.requests[3].jsonBody == ["name": "release/*/*"])
        #expect(transport.requests[8].jsonBody == ["integration_id": 7])
    }
}
