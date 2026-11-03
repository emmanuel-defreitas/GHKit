import Foundation
import Testing

@testable import GHKit

@Suite("Issues")
struct IssuesTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func issueModelsDecode() throws {
        let issue = try decoder.decode(GitHubIssue.self, from: loadFixture("issue"))
        #expect(issue.number == 1347)
        #expect(issue.state == .open)
        #expect(issue.title == "Found a bug")
        #expect(issue.labels.first?.name == "bug")
        #expect(issue.labels.first?.color == "f29513")
        #expect(issue.assignees?.first?.login == "octocat")
        #expect(issue.milestone?.number == 1)
        #expect(issue.isLocked)
        #expect(issue.activeLockReason == "too heated")
        #expect(issue.commentCount == 0)
        #expect(issue.isPullRequest)
        #expect(issue.authorAssociation == .collaborator)
        #expect(issue.pinnedComment == nil)

        let items = try decoder.decode([GitHubIssue].self, from: loadFixture("issue-with-repo-items"))
        #expect(items.first?.repository?.fullName == "octocat/Hello-World")
        _ = try decoder.decode([GitHubIssue].self, from: loadFixture("issue-items"))

        let pinned = try decoder.decode(GitHubIssue.self, from: loadFixture("issue-with-pinned-comment"))
        #expect(pinned.pinnedComment?.body == "Me too")
    }

    @Test func labelsCanBeBareNames() throws {
        let labels = try decoder.decode([IssueLabel].self, from: Data(#"["bug", {"name": "docs", "color": "0075ca"}]"#.utf8))
        #expect(labels.map(\.name) == ["bug", "docs"])
        #expect(labels[0].id == nil)
        #expect(labels[1].color == "0075ca")
    }

    @Test func commentLabelAndMilestoneModelsDecode() throws {
        let comment = try decoder.decode(IssueComment.self, from: loadFixture("issue-comment"))
        #expect(comment.body == "Me too")
        #expect(comment.authorAssociation == .collaborator)
        #expect(comment.pin == nil)
        _ = try decoder.decode([IssueComment].self, from: loadFixture("issue-comment-items"))

        let pinned = try decoder.decode(IssueComment.self, from: loadFixture("issue-comment-pinned"))
        #expect(pinned.pin?.pinnedBy?.login == "octocat")

        let label = try decoder.decode(IssueLabel.self, from: loadFixture("label"))
        #expect(label.name == "bug")
        #expect(label.isDefault == true)
        _ = try decoder.decode([IssueLabel].self, from: loadFixture("label-items"))

        let milestone = try decoder.decode(Milestone.self, from: loadFixture("milestone"))
        #expect(milestone.title == "v1.0")
        #expect(milestone.state == .open)
        #expect(milestone.openIssues == 4)
        #expect(milestone.dueOn != nil)
        _ = try decoder.decode([Milestone].self, from: loadFixture("milestone-items"))
    }

    @Test func commentRoundTrips() throws {
        let comment = try decoder.decode(
            IssueComment.self,
            from: Data(
                #"""
                {"id": 1, "node_id": "IC_1", "body": "Spam", "url": "https://api.github.com/x", "html_url": "https://github.com/x",
                 "issue_url": "https://api.github.com/i", "created_at": "2024-01-01T00:00:00Z", "updated_at": "2024-01-01T00:00:00Z",
                 "minimized": {"reason": "spam"}}
                """#.utf8))
        #expect(comment.minimizedReason == "spam")
        let again = try decoder.decode(IssueComment.self, from: GitHubJSON.encoder().encode(comment))
        #expect(again == comment)
    }

    // MARK: Issues

    @Test func listsAcrossRepositories() async throws {
        let transport = MockTransport(.fixture("issue-with-repo-items"))
        let issues = makeClient(transport).issues
        _ = try await issues.list().collect()
        _ = try await issues.list(.created, in: .personalRepositories, matching: IssueFilter(state: .all, labels: ["bug", "ui"])).collect()
        let since = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await issues.list(
            .mentioned, in: .organization("acme"), matching: IssueFilter(updatedSince: since, type: "Bug", creator: "mona"),
            sort: .updated, ascending: true
        ).collect()
        #expect(transport.requests.map(\.path) == ["/issues", "/user/issues", "/orgs/acme/issues"])
        #expect(transport.requests[0].queryItems == ["filter": "assigned", "state": "open", "sort": "created", "per_page": "100"])
        #expect(
            transport.requests[1].queryItems == [
                "filter": "created", "state": "all", "labels": "bug,ui", "sort": "created", "per_page": "100",
            ])
        // Repository-only filters are left out.
        #expect(
            transport.requests[2].queryItems == [
                "filter": "mentioned", "state": "open", "since": "2023-11-14T22:13:20Z", "type": "Bug", "sort": "updated",
                "direction": "asc", "per_page": "100",
            ])
    }

    @Test func listsARepository() async throws {
        let transport = MockTransport(.fixture("issue-items"))
        let issues = makeClient(transport).issues
        _ = try await issues.list(
            "octocat", "Hello-World",
            matching: IssueFilter(state: .closed, milestone: .noMilestone, assignee: .user("mona"), creator: "hubot", mentioned: "octocat"),
            sort: .comments
        ).collect()
        _ = try await issues.list("octocat", "Hello-World", matching: IssueFilter(milestone: .number(3), assignee: .unassigned)).collect()
        _ = try await issues.list("octocat", "Hello-World", matching: IssueFilter(milestone: .any, assignee: .anyone)).collect()
        #expect(transport.requests[0].path == "/repos/octocat/Hello-World/issues")
        #expect(
            transport.requests[0].queryItems == [
                "state": "closed", "milestone": "none", "assignee": "mona", "creator": "hubot", "mentioned": "octocat",
                "sort": "comments", "per_page": "100",
            ])
        #expect(transport.requests[1].queryItems["milestone"] == "3")
        #expect(transport.requests[1].queryItems["assignee"] == "none")
        #expect(transport.requests[2].queryItems["milestone"] == "*")
        #expect(transport.requests[2].queryItems["assignee"] == "*")
    }

    @Test func createsAndUpdates() async throws {
        let transport = MockTransport(.fixture("issue", status: 201))
        let issues = makeClient(transport).issues
        let issue = try await issues.create(
            NewIssue(title: "Found a bug", body: "Details", assignees: ["octocat"], milestone: 1, labels: ["bug"], type: "Bug"),
            in: "octocat", "Hello-World")
        #expect(issue.number == 1347)
        _ = try await issues.create(NewIssue(title: "Child", parentIssueID: 42), in: "octocat", "Hello-World")
        _ = try await issues.update(
            1347, in: "octocat", "Hello-World",
            IssueUpdate(title: "New title", assignees: [], labels: ["ui"], milestone: .remove, type: .set("Feature")))
        _ = try await issues.update(1347, in: "octocat", "Hello-World", IssueUpdate(milestone: .set(2), type: .remove))
        _ = try await issues.close(1347, in: "octocat", "Hello-World", reason: .notPlanned)
        _ = try await issues.update(
            1347, in: "octocat", "Hello-World", IssueUpdate(state: .closed, stateReason: .duplicate, duplicateOf: 99))
        _ = try await issues.reopen(1347, in: "octocat", "Hello-World")

        #expect(transport.requests[0].route == "POST /repos/octocat/Hello-World/issues")
        #expect(
            transport.requests[0].jsonBody == [
                "title": "Found a bug", "body": "Details", "assignees": ["octocat"], "milestone": 1, "labels": ["bug"], "type": "Bug",
            ])
        #expect(transport.requests[1].jsonBody == ["title": "Child", "parent_issue_id": 42])
        #expect(transport.requests[2].route == "PATCH /repos/octocat/Hello-World/issues/1347")
        #expect(
            transport.requests[2].jsonBody == [
                "title": "New title", "assignees": [], "labels": ["ui"], "milestone": nil, "type": "Feature",
            ])
        #expect(transport.requests[3].jsonBody == ["milestone": 2, "type": nil])
        #expect(transport.requests[4].jsonBody == ["state": "closed", "state_reason": "not_planned"])
        #expect(transport.requests[5].jsonBody == ["state": "closed", "state_reason": "duplicate", "duplicate_issue_id": 99])
        #expect(transport.requests[6].jsonBody == ["state": "open"])
    }

    @Test func fetchesOneIssue() async throws {
        let transport = MockTransport(.fixture("issue"))
        let issue = try await makeClient(transport).issues.issue(1347, in: "octocat", "Hello-World")
        #expect(issue.title == "Found a bug")
        #expect(transport.requests.map(\.route) == ["GET /repos/octocat/Hello-World/issues/1347"])
    }

    @Test func locksAndUnlocks() async throws {
        let transport = MockTransport(.noContent())
        let issues = makeClient(transport).issues
        try await issues.lock(1347, in: "octocat", "Hello-World", reason: .offTopic)
        try await issues.lock(1347, in: "octocat", "Hello-World")
        try await issues.unlock(1347, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "PUT /repos/octocat/Hello-World/issues/1347/lock", "PUT /repos/octocat/Hello-World/issues/1347/lock",
                "DELETE /repos/octocat/Hello-World/issues/1347/lock",
            ])
        #expect(transport.requests[0].jsonBody == ["lock_reason": "off-topic"])
        #expect(transport.requests[1].jsonBody == [:])
    }

    // MARK: Assignees

    @Test func assignees() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", "/repos/octocat/Hello-World/assignees"): .fixture("simple-user-items")
            case ("GET", "/repos/octocat/Hello-World/assignees/mona"): .noContent()
            case ("GET", _): .json(#"{"message":"Not Found"}"#, status: 404)
            default: .fixture("issue")
            }
        }
        let issues = makeClient(transport).issues
        let people = try await issues.assignees("octocat", "Hello-World").collect()
        #expect(people.first?.login == "octocat")
        #expect(try await issues.canAssign("mona", in: "octocat", "Hello-World"))
        #expect(try await issues.canAssign("hubot", to: 1347, in: "octocat", "Hello-World") == false)
        _ = try await issues.addAssignees(["mona", "hubot"], to: 1347, in: "octocat", "Hello-World")
        _ = try await issues.removeAssignees(["hubot"], from: 1347, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/assignees", "GET /repos/octocat/Hello-World/assignees/mona",
                "GET /repos/octocat/Hello-World/issues/1347/assignees/hubot", "POST /repos/octocat/Hello-World/issues/1347/assignees",
                "DELETE /repos/octocat/Hello-World/issues/1347/assignees",
            ])
        #expect(transport.requests[3].jsonBody == ["assignees": ["mona", "hubot"]])
        #expect(transport.requests[4].jsonBody == ["assignees": ["hubot"]])
    }

    // MARK: Comments

    @Test func comments() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "DELETE": .noContent()
            case "PUT": .fixture("issue-comment-pinned")
            case "GET" where request.path.hasSuffix("comments"): .fixture("issue-comment-items")
            default: .fixture("issue-comment")
            }
        }
        let issues = makeClient(transport).issues
        let since = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await issues.comments(on: 1347, in: "octocat", "Hello-World", updatedSince: since).collect()
        _ = try await issues.comments("octocat", "Hello-World", sort: .updated, ascending: false).collect()
        _ = try await issues.comment(id: 1, in: "octocat", "Hello-World")
        _ = try await issues.createComment("Me too", on: 1347, in: "octocat", "Hello-World")
        _ = try await issues.updateComment(id: 1, in: "octocat", "Hello-World", body: "Me three")
        let pinned = try await issues.pinComment(id: 1, in: "octocat", "Hello-World")
        #expect(pinned.pin != nil)
        try await issues.unpinComment(id: 1, in: "octocat", "Hello-World")
        try await issues.deleteComment(id: 1, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issues/1347/comments", "GET /repos/octocat/Hello-World/issues/comments",
                "GET /repos/octocat/Hello-World/issues/comments/1", "POST /repos/octocat/Hello-World/issues/1347/comments",
                "PATCH /repos/octocat/Hello-World/issues/comments/1", "PUT /repos/octocat/Hello-World/issues/comments/1/pin",
                "DELETE /repos/octocat/Hello-World/issues/comments/1/pin", "DELETE /repos/octocat/Hello-World/issues/comments/1",
            ])
        #expect(transport.requests[0].queryItems == ["since": "2023-11-14T22:13:20Z", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["sort": "updated", "direction": "desc", "per_page": "100"])
        #expect(transport.requests[3].jsonBody == ["body": "Me too"])
        #expect(transport.requests[4].jsonBody == ["body": "Me three"])
    }

    // MARK: Labels

    @Test func repositoryLabels() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "DELETE": .noContent()
            case "GET" where request.path.hasSuffix("labels"): .fixture("label-items")
            case "PATCH": .fixture("label-2")
            default: .fixture("label")
            }
        }
        let issues = makeClient(transport).issues
        _ = try await issues.labels("octocat", "Hello-World").collect()
        _ = try await issues.label(named: "good first issue", in: "octocat", "Hello-World")
        _ = try await issues.createLabel(NewLabel(name: "bug", color: "f29513", description: "Broken"), in: "octocat", "Hello-World")
        _ = try await issues.updateLabel(
            named: "bug", in: "octocat", "Hello-World", LabelUpdate(name: "bug :bug:", color: "b01f26", isArchived: true))
        try await issues.deleteLabel(named: "area/ui", in: "octocat", "Hello-World")
        _ = try await issues.labels(inMilestone: 1, in: "octocat", "Hello-World").collect()
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/labels", "GET /repos/octocat/Hello-World/labels/good%20first%20issue",
                "POST /repos/octocat/Hello-World/labels", "PATCH /repos/octocat/Hello-World/labels/bug",
                "DELETE /repos/octocat/Hello-World/labels/area%2Fui", "GET /repos/octocat/Hello-World/milestones/1/labels",
            ])
        #expect(transport.requests[2].jsonBody == ["name": "bug", "color": "f29513", "description": "Broken"])
        #expect(transport.requests[3].jsonBody == ["new_name": "bug :bug:", "color": "b01f26", "archived": true])
    }

    @Test func issueLabels() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "DELETE" && request.path.hasSuffix("labels") ? .noContent() : .fixture("label-items")
        }
        let issues = makeClient(transport).issues
        _ = try await issues.labels(on: 1347, in: "octocat", "Hello-World").collect()
        let labels = try await issues.addLabels(["bug", "ui"], to: 1347, in: "octocat", "Hello-World")
        #expect(labels.first?.name == "bug")
        _ = try await issues.setLabels([], on: 1347, in: "octocat", "Hello-World")
        _ = try await issues.removeLabel(named: "bug", from: 1347, in: "octocat", "Hello-World")
        try await issues.removeAllLabels(from: 1347, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/issues/1347/labels", "POST /repos/octocat/Hello-World/issues/1347/labels",
                "PUT /repos/octocat/Hello-World/issues/1347/labels", "DELETE /repos/octocat/Hello-World/issues/1347/labels/bug",
                "DELETE /repos/octocat/Hello-World/issues/1347/labels",
            ])
        #expect(transport.requests[1].jsonBody == ["labels": ["bug", "ui"]])
        #expect(transport.requests[2].jsonBody == ["labels": []])
    }

    // MARK: Milestones

    @Test func milestones() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "DELETE": .noContent()
            case "GET" where request.path.hasSuffix("milestones"): .fixture("milestone-items")
            default: .fixture("milestone")
            }
        }
        let issues = makeClient(transport).issues
        _ = try await issues.milestones("octocat", "Hello-World", state: .all, sort: .completeness, ascending: false).collect()
        _ = try await issues.milestone(1, in: "octocat", "Hello-World")
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await issues.createMilestone(NewMilestone(title: "v1.0", description: "First", dueOn: due), in: "octocat", "Hello-World")
        _ = try await issues.updateMilestone(1, in: "octocat", "Hello-World", MilestoneUpdate(state: .closed))
        try await issues.deleteMilestone(1, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/milestones", "GET /repos/octocat/Hello-World/milestones/1",
                "POST /repos/octocat/Hello-World/milestones", "PATCH /repos/octocat/Hello-World/milestones/1",
                "DELETE /repos/octocat/Hello-World/milestones/1",
            ])
        #expect(transport.requests[0].queryItems == ["state": "all", "sort": "completeness", "direction": "desc", "per_page": "100"])
        #expect(transport.requests[2].jsonBody == ["title": "v1.0", "description": "First", "due_on": "2023-11-14T22:13:20Z"])
        #expect(transport.requests[3].jsonBody == ["state": "closed"])
    }
}
