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

@Suite("Issue details")
struct IssueDetailsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func eventModelsDecode() throws {
        let event = try decoder.decode(IssueEvent.self, from: loadFixture("issue-event"))
        #expect(event.event == .closed)
        #expect(event.commitID == "6dcb09b5b57875f334f61aebed695e2e4193db5e")
        #expect(event.issue?.number == 1347)
        _ = try decoder.decode([IssueEvent].self, from: loadFixture("issue-event-items"))
        _ = try decoder.decode([IssueEvent].self, from: loadFixture("issue-event-for-issue-items"))
    }

    @Test func eventExtrasDecodeAndRoundTrip() throws {
        let json = #"""
            {"id": 7, "node_id": "E_7", "event": "sub_issue_added", "created_at": "2024-01-01T00:00:00Z",
             "actor": null, "commit_id": null, "commit_url": null,
             "label": {"name": "bug", "color": "f29513"}, "milestone": {"title": "v1.0"},
             "rename": {"from": "Old", "to": "New"}, "issue_type": {"id": 3, "name": "Bug", "color": "red"},
             "sub_issue": {"number": 12, "title": "Child", "state": "open",
               "repository": {"id": 1, "node_id": "R_1", "name": "Hello-World", "full_name": "octocat/Hello-World",
                 "private": false, "owner": {"login": "octocat", "id": 1, "node_id": "U_1", "type": "User"}},
               "issue_type": null},
             "dismissed_review": {"state": "dismissed", "review_id": 9, "dismissal_message": "Stale"},
             "intent": {"rationale": "Looks like a bug", "confidence": "HIGH"}}
            """#
        let event = try decoder.decode(IssueEvent.self, from: Data(json.utf8))
        #expect(event.event == .subIssueAdded)
        #expect(event.label?.name == "bug")
        #expect(event.milestoneTitle == "v1.0")
        #expect(event.rename?.to == "New")
        #expect(event.issueType?.color == .red)
        #expect(event.subIssue?.repository.fullName == "octocat/Hello-World")
        #expect(event.dismissedReview?.reviewID == 9)
        #expect(event.intent?.confidence == .high)
        let again = try decoder.decode(IssueEvent.self, from: GitHubJSON.encoder().encode(event))
        #expect(again == event)
    }

    @Test func fieldTypeSuggestionAndArtifactModelsDecode() throws {
        let fields = try decoder.decode([IssueField].self, from: loadFixture("issue-field-items"))
        #expect(fields.map(\.dataType) == [.text, .singleSelect, .multiSelect])
        #expect(fields[1].options?.count == 3)
        _ = try decoder.decode(IssueField.self, from: loadFixture("issue-field"))

        let values = try decoder.decode([IssueFieldValue].self, from: loadFixture("issue-field-value-items"))
        #expect(values.first?.value == "DRI")
        #expect(values.map(\.dataType).contains(.date))

        let types = try decoder.decode([IssueType].self, from: loadFixture("issue-type-items"))
        #expect(types.map(\.name) == ["Task", "Bug"])
        _ = try decoder.decode(IssueType.self, from: loadFixture("issue-type"))

        let suggestion = try decoder.decode(IssueSuggestion.self, from: loadFixture("issue-suggestion"))
        #expect(suggestion.state == .approved)
        #expect(suggestion.action == .addLabel)
        let suggestions = try decoder.decode([IssueSuggestion].self, from: loadFixture("issue-suggestions"))
        #expect(suggestions.first?.confidence == .high)

        let artifacts = try decoder.decode([IssueArtifact].self, from: loadFixture("issue-artifact-items"))
        #expect(artifacts.map(\.type) == [.plan, .link])
        let history = try decoder.decode(IssueArtifactHistory.self, from: loadFixture("issue-artifact-with-versions"))
        #expect(history.artifact.name == "Updated implementation plan")
        #expect(history.versions.first?.version == 2)
        let plain = try decoder.decode(IssueArtifactHistory.self, from: loadFixture("issue-artifact"))
        #expect(plain.artifact.type == .generic)
        #expect(plain.versions.isEmpty)
    }

    // MARK: Events

    @Test func events() async throws {
        let transport = MockTransport { request, _ in
            request.path.hasSuffix("/events") ? .fixture("issue-event-items") : .fixture("issue-event")
        }
        let issues = makeClient(transport).issues
        _ = try await issues.events("octocat", "Hello-World").collect()
        _ = try await issues.event(id: 1, in: "octocat", "Hello-World")
        _ = try await issues.events(on: 1347, in: "octocat", "Hello-World").collect()
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issues/events", "GET /repos/octocat/Hello-World/issues/events/1",
                "GET /repos/octocat/Hello-World/issues/1347/events",
            ])
    }

    // MARK: Sub-issues and dependencies

    @Test(arguments: [true, false])
    func parentIsNilWithoutOne(hasParent: Bool) async throws {
        let transport = MockTransport(hasParent ? .fixture("issue") : .json(#"{"message":"Not Found"}"#, status: 404))
        let parent = try await makeClient(transport).issues.parent(of: 12, in: "octocat", "Hello-World")
        #expect((parent != nil) == hasParent)
        #expect(transport.requests.map(\.route) == ["GET /repos/octocat/Hello-World/issues/12/parent"])
    }

    @Test func subIssues() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("issue-items") : .fixture("issue")
        }
        let issues = makeClient(transport).issues
        _ = try await issues.subIssues(of: 1347, in: "octocat", "Hello-World").collect()
        _ = try await issues.addSubIssue(id: 55, to: 1347, in: "octocat", "Hello-World")
        _ = try await issues.addSubIssue(id: 56, to: 1347, in: "octocat", "Hello-World", replaceParent: true)
        _ = try await issues.removeSubIssue(id: 55, from: 1347, in: "octocat", "Hello-World")
        _ = try await issues.moveSubIssue(id: 56, .after(57), of: 1347, in: "octocat", "Hello-World")
        _ = try await issues.moveSubIssue(id: 56, .before(58), of: 1347, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issues/1347/sub_issues", "POST /repos/octocat/Hello-World/issues/1347/sub_issues",
                "POST /repos/octocat/Hello-World/issues/1347/sub_issues", "DELETE /repos/octocat/Hello-World/issues/1347/sub_issue",
                "PATCH /repos/octocat/Hello-World/issues/1347/sub_issues/priority",
                "PATCH /repos/octocat/Hello-World/issues/1347/sub_issues/priority",
            ])
        #expect(transport.requests[1].jsonBody == ["sub_issue_id": 55])
        #expect(transport.requests[2].jsonBody == ["sub_issue_id": 56, "replace_parent": true])
        #expect(transport.requests[3].jsonBody == ["sub_issue_id": 55])
        #expect(transport.requests[4].jsonBody == ["sub_issue_id": 56, "after_id": 57])
        #expect(transport.requests[5].jsonBody == ["sub_issue_id": 56, "before_id": 58])
    }

    @Test func dependenciesAndRelatedIssues() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("issue-items") : .fixture("issue")
        }
        let issues = makeClient(transport).issues
        _ = try await issues.blockers(of: 1347, in: "octocat", "Hello-World").collect()
        _ = try await issues.blockedIssues(by: 1347, in: "octocat", "Hello-World").collect()
        _ = try await issues.addBlocker(id: 9, to: 1347, in: "octocat", "Hello-World")
        _ = try await issues.removeBlocker(id: 9, from: 1347, in: "octocat", "Hello-World")
        _ = try await issues.relatedIssues(to: 1347, in: "octocat", "Hello-World").collect()
        _ = try await issues.addRelatedIssue(id: 10, to: 1347, in: "octocat", "Hello-World")
        _ = try await issues.removeRelatedIssue(id: 10, from: 1347, in: "octocat", "Hello-World")
        let base = "/repos/octocat/Hello-World/issues/1347"
        #expect(
            transport.requests.map(\.route) == [
                "GET \(base)/dependencies/blocked_by", "GET \(base)/dependencies/blocking", "POST \(base)/dependencies/blocked_by",
                "DELETE \(base)/dependencies/blocked_by/9", "GET \(base)/relates_to", "POST \(base)/relates_to",
                "DELETE \(base)/relates_to/10",
            ])
        #expect(transport.requests[2].jsonBody == ["issue_id": 9])
        #expect(transport.requests[5].jsonBody == ["issue_id": 10])
    }

    // MARK: Fields and types

    @Test func fieldValues() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" ? .noContent() : .fixture("issue-field-value-items")
        }
        let issues = makeClient(transport).issues
        let values = try await issues.fieldValues(of: 1347, in: "octocat", "Hello-World").collect()
        #expect(values.count == 5)
        _ = try await issues.addFieldValues(
            [NewIssueFieldValue(fieldID: 1, value: .text("DRI")), NewIssueFieldValue(fieldID: 3, value: .number(42))],
            to: 1347, in: "octocat", "Hello-World")
        _ = try await issues.setFieldValues(
            [NewIssueFieldValue(fieldID: 5, value: .options(["Frontend", "Backend"]))], on: 1347, in: "octocat", "Hello-World")
        try await issues.deleteFieldValue(fieldID: 2, from: 1347, in: "octocat", "Hello-World")
        let base = "/repos/octocat/Hello-World/issues/1347/issue-field-values"
        #expect(transport.requests.map(\.route) == ["GET \(base)", "POST \(base)", "PUT \(base)", "DELETE \(base)/2"])
        #expect(
            transport.requests[1].jsonBody == [
                "issue_field_values": [["field_id": 1, "value": "DRI"], ["field_id": 3, "value": 42]]
            ])
        #expect(transport.requests[2].jsonBody == ["issue_field_values": [["field_id": 5, "value": ["Frontend", "Backend"]]]])
    }

    @Test func issuesCarryFieldValues() async throws {
        let transport = MockTransport(.fixture("issue"))
        let issues = makeClient(transport).issues
        _ = try await issues.create(
            NewIssue(title: "Bug", fieldValues: [NewIssueFieldValue(fieldID: 2, value: .text("High"))]), in: "octocat", "Hello-World")
        _ = try await issues.update(1347, in: "octocat", "Hello-World", IssueUpdate(fieldValues: []))
        #expect(transport.requests[0].jsonBody == ["title": "Bug", "issue_field_values": [["field_id": 2, "value": "High"]]])
        #expect(transport.requests[1].jsonBody == ["issue_field_values": []])
    }

    @Test func organizationTypesAndFields() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("DELETE", _): .noContent()
            case ("GET", let path) where path.hasSuffix("issue-types"): .fixture("issue-type-items")
            case ("GET", _): .fixture("issue-field-items")
            case (_, let path) where path.contains("issue-types"): .fixture("issue-type")
            default: .fixture("issue-field")
            }
        }
        let issues = makeClient(transport).issues
        _ = try await issues.types("octocat", "Hello-World")
        _ = try await issues.types(in: "acme")
        _ = try await issues.createType(IssueTypeInput(name: "Epic", description: "Big work", color: .purple), in: "acme")
        _ = try await issues.updateType(id: 4, in: "acme", IssueTypeInput(name: "Epic", isEnabled: false))
        try await issues.deleteType(id: 4, in: "acme")
        _ = try await issues.fields(in: "acme")
        _ = try await issues.createField(
            NewIssueField(
                name: "Priority", dataType: .singleSelect, visibility: .all,
                options: [IssueFieldOptionInput(name: "High", color: .red, priority: 1)]),
            in: "acme")
        _ = try await issues.updateField(
            id: 2, in: "acme", IssueFieldUpdate(name: "Urgency", options: [IssueFieldOptionInput(id: 7, name: "High", color: .red, priority: 1)]))
        try await issues.deleteField(id: 2, in: "acme")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issue-types", "GET /orgs/acme/issue-types", "POST /orgs/acme/issue-types",
                "PUT /orgs/acme/issue-types/4", "DELETE /orgs/acme/issue-types/4", "GET /orgs/acme/issue-fields",
                "POST /orgs/acme/issue-fields", "PATCH /orgs/acme/issue-fields/2", "DELETE /orgs/acme/issue-fields/2",
            ])
        #expect(transport.requests[2].jsonBody == ["name": "Epic", "is_enabled": true, "description": "Big work", "color": "purple"])
        #expect(transport.requests[3].jsonBody == ["name": "Epic", "is_enabled": false])
        #expect(
            transport.requests[6].jsonBody == [
                "name": "Priority", "data_type": "single_select", "visibility": "all",
                "options": [["name": "High", "color": "red", "priority": 1]],
            ])
        #expect(
            transport.requests[7].jsonBody == [
                "name": "Urgency", "options": [["id": 7, "name": "High", "color": "red", "priority": 1]],
            ])
    }

    // MARK: Suggestions and artifacts

    @Test func suggestions() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("issue-suggestions") : .fixture("issue-suggestion")
        }
        let issues = makeClient(transport).issues
        _ = try await issues.suggestions(for: 1347, in: "octocat", "Hello-World").collect()
        _ = try await issues.suggestions(for: 1347, in: "octocat", "Hello-World", state: nil, action: .setType).collect()
        _ = try await issues.approveSuggestion(id: 12, on: 1347, in: "octocat", "Hello-World")
        _ = try await issues.dismissSuggestion(id: 13, on: 1347, in: "octocat", "Hello-World")
        let base = "/repos/octocat/Hello-World/issues/1347/suggestions"
        #expect(
            transport.requests.map(\.route) == ["GET \(base)", "GET \(base)", "POST \(base)/12/approve", "POST \(base)/13/dismiss"])
        #expect(transport.requests[0].queryItems == ["state": "pending", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["state": "all", "action": "set_type", "per_page": "100"])
    }

    @Test func artifacts() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "DELETE": .noContent()
            case "GET" where request.path.hasSuffix("artifacts"): .fixture("issue-artifact-items")
            case "GET": .fixture("issue-artifact-with-versions")
            default: .fixture("issue-artifact")
            }
        }
        let issues = makeClient(transport).issues
        _ = try await issues.artifacts(on: 1347, in: "octocat", "Hello-World", type: .plan).collect()
        let history = try await issues.artifact(1, on: 1347, in: "octocat", "Hello-World")
        #expect(history.versions.count == 2)
        _ = try await issues.createArtifact(
            NewIssueArtifact(name: "Research notes", body: "## Findings", type: .generic), on: 1347, in: "octocat", "Hello-World")
        _ = try await issues.updateArtifact(1, on: 1347, in: "octocat", "Hello-World", body: "## Revised")
        try await issues.deleteArtifact(1, on: 1347, in: "octocat", "Hello-World")
        let base = "/repos/octocat/Hello-World/issues/1347/artifacts"
        #expect(
            transport.requests.map(\.route) == ["GET \(base)", "GET \(base)/1", "POST \(base)", "PATCH \(base)/1", "DELETE \(base)/1"])
        #expect(transport.requests[0].queryItems == ["type": "plan", "per_page": "100"])
        #expect(transport.requests[2].jsonBody == ["name": "Research notes", "body": "## Findings", "type": "generic"])
        #expect(transport.requests[3].jsonBody == ["body": "## Revised"])
    }

    @Test func artifactsPageByNumberWithoutLinkHeaders() async throws {
        // Two artifacts per full page, then a short page. GitHub sends no `Link` header here.
        let transport = MockTransport { request, _ in
            switch request.queryItems["page"] {
            case nil, "2": .fixture("issue-artifact-items")
            default: .fixtureList("issue-artifact")
            }
        }
        let artifacts = try await makeClient(transport).issues.artifacts(on: 1347, in: "octocat", "Hello-World", perPage: 2).collect()
        #expect(artifacts.count == 5)
        #expect(transport.requests.map { $0.queryItems["page"] } == [nil, "2", "3"])
        #expect(transport.requests.allSatisfy { $0.queryItems["per_page"] == "2" })
    }
}
