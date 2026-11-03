import Foundation
import Testing

@testable import GHKit

@Suite("Pull requests")
struct PullRequestsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func pullRequestModelsDecode() throws {
        let pull = try decoder.decode(PullRequest.self, from: loadFixture("pull-request"))
        #expect(pull.number == 1347)
        #expect(pull.state == .open)
        #expect(pull.head.ref == "new-topic")
        #expect(pull.base.ref == "master")
        #expect(pull.head.repository?.fullName == "octocat/Hello-World")
        #expect(pull.isMerged == false)
        #expect(pull.isMergeable == true)
        #expect(pull.mergeableState == .clean)
        #expect(pull.commitCount == 3)
        #expect(pull.requestedTeams?.first?.slug == "justice-league")
        #expect(pull.labels.first?.name == "bug")

        let items = try decoder.decode([PullRequest].self, from: loadFixture("pull-request-simple-items"))
        #expect(items.first?.isMerged == nil)
        _ = try decoder.decode(PullRequest.self, from: loadFixture("pull-request-simple"))
    }

    @Test func reviewModelsDecode() throws {
        let review = try decoder.decode(PullRequestReview.self, from: loadFixture("pull-request-review"))
        #expect(review.id == 80)
        #expect(review.state == .changesRequested)
        _ = try decoder.decode([PullRequestReview].self, from: loadFixture("pull-request-review-items"))

        let comment = try decoder.decode(ReviewComment.self, from: loadFixture("pull-request-review-comment-example-for-a-multi-line-comment"))
        #expect(comment.startLine == 1)
        #expect(comment.line == 2)
        #expect(comment.side == .right)
        _ = try decoder.decode([ReviewComment].self, from: loadFixture("pull-request-review-comment-items"))
        _ = try decoder.decode([ReviewComment].self, from: loadFixture("review-comment-items"))

        let requests = try decoder.decode(ReviewRequests.self, from: loadFixture("simple-pull-request-review-request"))
        #expect(requests.users.first?.login == "octocat")
        #expect(requests.teams.first?.slug == "justice-league")
    }

    @Test func mergeAndStackModelsDecode() throws {
        let result = try decoder.decode(MergeResult.self, from: loadFixture("pull-request-merge-result-response-if-merge-was-successful"))
        #expect(result.isMerged)

        let pending = try decoder.decode(BackgroundMerge.self, from: loadFixture("pull-request-merge-async-pending"))
        #expect(pending.status == .pending)
        #expect(pending.details.uuid == "630b9d5e-3f2a-4f7e-8b0c-2d5f9a8c1e42")
        #expect(pending.details.mergeAction == .mergeQueue)
        let merged = try decoder.decode(BackgroundMerge.self, from: loadFixture("pull-request-merge-async-merged"))
        #expect(merged.status == .merged)
        #expect(merged.details.sha == "6dcb09b5b57875f334f61aebed695e2e4193db5e")

        let stacks = try decoder.decode([PullRequestStack].self, from: loadFixture("pull-request-stack-items"))
        #expect(stacks.first?.pullRequests.map(\.number) == [101, 102])
        #expect(stacks.first?.pullRequests.first?.head?.ref == "user-model")
        let stack = try decoder.decode(PullRequestStack.self, from: loadFixture("pull-request-stack"))
        #expect(stack.isOpen)
        #expect(stack.base.ref == "main")
        #expect(stack.pullRequests.first?.title == "Add user model")
    }

    @Test func timelineDecodes() throws {
        let timeline = try decoder.decode([TimelineEvent].self, from: loadFixture("timeline-issue-events"))
        #expect(timeline.map(\.type) == [.locked, .labeled, .renamed, "commented"])
        guard case .event(let locked) = timeline[0], case .commented(let comment) = timeline[3] else {
            Issue.record("Unexpected timeline entries: \(timeline)")
            return
        }
        #expect(locked.event == .locked)
        #expect(locked.lockReason == nil)
        #expect(comment.body?.isEmpty == false)

        let json = #"""
            [{"event": "cross-referenced", "created_at": "2024-01-01T00:00:00Z", "updated_at": "2024-01-01T00:00:00Z",
              "source": {"type": "issue"}},
             {"sha": "abc", "node_id": "C_1", "message": "Fix",
              "author": {"name": "Mona", "email": "mona@example.com", "date": "2024-01-01T00:00:00Z"},
              "committer": {"name": "Mona", "email": "mona@example.com", "date": "2024-01-01T00:00:00Z"},
              "tree": {"sha": "t"}, "parents": [], "html_url": "https://github.com/c"},
             {"event": "line-commented", "node_id": "L_1", "comments": []},
             {"event": "commit-commented", "commit_id": "abc", "comments": []},
             {"event": "connected_in_space", "actor": null}]
            """#
        let entries = try decoder.decode([TimelineEvent].self, from: Data(json.utf8))
        #expect(entries.map(\.type) == ["cross-referenced", "committed", "line-commented", "commit-commented", "connected_in_space"])
        if case .committed(let commit) = entries[1] { #expect(commit.message == "Fix") } else { Issue.record("Not a commit") }
        if case .unknown(_, let raw) = entries[4] { #expect(raw["event"] == "connected_in_space") } else { Issue.record("Not unknown") }

        let again = try decoder.decode([TimelineEvent].self, from: GitHubJSON.encoder().encode(entries + timeline))
        #expect(again == entries + timeline)
    }

    // MARK: Pull requests

    @Test func listsAndFetches() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case let path where path.hasSuffix("/pulls"): .fixture("pull-request-simple-items")
            case let path where path.hasSuffix("/commits"): .fixture("commit-items")
            case let path where path.hasSuffix("/files"): .fixture("diff-entry-items")
            case let path where path.hasSuffix("/pulls/1347") && request.value(forHTTPHeaderField: "Accept")!.hasSuffix("diff"):
                MockResponse(body: Data("diff --git a/x b/x".utf8))
            default: .fixture("pull-request")
            }
        }
        let pulls = makeClient(transport).pullRequests
        _ = try await pulls.list(
            "octocat", "Hello-World", state: .all, head: "octocat:new-topic", base: "main", sort: .longRunning, ascending: true
        ).collect()
        let pull = try await pulls.pullRequest(1347, in: "octocat", "Hello-World")
        #expect(pull.title == "Amazing new feature")
        let diff = try await pulls.diff(1347, in: "octocat", "Hello-World")
        #expect(diff.hasPrefix("diff --git"))
        _ = try await pulls.commits(of: 1347, in: "octocat", "Hello-World").collect()
        let files = try await pulls.files(of: 1347, in: "octocat", "Hello-World").collect()
        #expect(files.first?.filename == "file1.txt")
        _ = try await pulls.pullRequests(containing: "6dcb09b", in: "octocat", "Hello-World").collect()
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/pulls", "GET /repos/octocat/Hello-World/pulls/1347",
                "GET /repos/octocat/Hello-World/pulls/1347", "GET /repos/octocat/Hello-World/pulls/1347/commits",
                "GET /repos/octocat/Hello-World/pulls/1347/files", "GET /repos/octocat/Hello-World/commits/6dcb09b/pulls",
            ])
        #expect(
            transport.requests[0].queryItems == [
                "state": "all", "head": "octocat:new-topic", "base": "main", "sort": "long-running", "direction": "asc",
                "per_page": "100",
            ])
        #expect(transport.requests[2].value(forHTTPHeaderField: "Accept") == "application/vnd.github.diff")
    }

    @Test func createsAndUpdates() async throws {
        let transport = MockTransport(.fixture("pull-request", status: 201))
        let pulls = makeClient(transport).pullRequests
        _ = try await pulls.create(
            NewPullRequest(title: "Amazing new feature", head: "octocat:new-topic", base: "master", body: "Please pull", isDraft: true),
            in: "octocat", "Hello-World")
        _ = try await pulls.create(
            NewPullRequest(source: .issue(12), head: "fix", base: "main", headRepository: "octocat/fork", maintainerCanModify: false),
            in: "octocat", "Hello-World")
        _ = try await pulls.update(1347, in: "octocat", "Hello-World", PullRequestUpdate(title: "Better", base: "develop"))
        _ = try await pulls.close(1347, in: "octocat", "Hello-World")
        _ = try await pulls.reopen(1347, in: "octocat", "Hello-World")
        #expect(transport.requests[0].route == "POST /repos/octocat/Hello-World/pulls")
        #expect(
            transport.requests[0].jsonBody == [
                "title": "Amazing new feature", "head": "octocat:new-topic", "base": "master", "body": "Please pull", "draft": true,
            ])
        #expect(
            transport.requests[1].jsonBody == [
                "issue": 12, "head": "fix", "base": "main", "head_repo": "octocat/fork", "maintainer_can_modify": false,
            ])
        #expect(transport.requests[2].route == "PATCH /repos/octocat/Hello-World/pulls/1347")
        #expect(transport.requests[2].jsonBody == ["title": "Better", "base": "develop"])
        #expect(transport.requests[3].jsonBody == ["state": "closed"])
        #expect(transport.requests[4].jsonBody == ["state": "open"])
    }

    // MARK: Merging

    @Test func merges() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", let path) where path.hasSuffix("/merge"): .noContent()
            case ("PUT", let path) where path.hasSuffix("/merge"): .fixture("pull-request-merge-result-response-if-merge-was-successful")
            case ("PUT", let path) where path.hasSuffix("/merge-async"): .fixture("pull-request-merge-async-pending", status: 202)
            case ("PUT", _): .json(#"{"message": "Updating pull request branch.", "url": "https://github.com/x"}"#, status: 202)
            default: .fixture("pull-request-merge-async-merged")
            }
        }
        let pulls = makeClient(transport).pullRequests
        #expect(try await pulls.isMerged(1347, in: "octocat", "Hello-World"))
        let result = try await pulls.merge(
            1347, in: "octocat", "Hello-World",
            MergeOptions(method: .squash, commitTitle: "Add feature (#1347)", expectedHeadSHA: "6dcb09b"))
        #expect(result.isMerged)
        _ = try await pulls.merge(1347, in: "octocat", "Hello-World")
        let pending = try await pulls.mergeInBackground(
            1347, in: "octocat", "Hello-World", MergeOptions(method: .merge), action: .mergeQueue, bypassRules: false)
        let uuid = try #require(pending.details.uuid)
        let merged = try await pulls.backgroundMerge(uuid, of: 1347, in: "octocat", "Hello-World")
        #expect(merged.status == .merged)
        try await pulls.updateBranch(1347, in: "octocat", "Hello-World", expectedHeadSHA: "6dcb09b")
        let base = "/repos/octocat/Hello-World/pulls/1347"
        #expect(
            transport.requests.map(\.route) == [
                "GET \(base)/merge", "PUT \(base)/merge", "PUT \(base)/merge", "PUT \(base)/merge-async", "GET \(base)/merge-async/\(uuid)",
                "PUT \(base)/update-branch",
            ])
        #expect(
            transport.requests[1].jsonBody == ["merge_method": "squash", "commit_title": "Add feature (#1347)", "sha": "6dcb09b"])
        #expect(transport.requests[2].jsonBody == [:])
        #expect(transport.requests[3].jsonBody == ["merge_method": "merge", "merge_action": "merge_queue", "bypass_rules": false])
        #expect(transport.requests[5].jsonBody == ["expected_head_sha": "6dcb09b"])
    }

    // MARK: Reviews

    @Test func reviewRequests() async throws {
        let transport = MockTransport { request, _ in
            request.httpMethod == "GET" ? .fixture("simple-pull-request-review-request") : .fixture("pull-request-review-request")
        }
        let pulls = makeClient(transport).pullRequests
        let requests = try await pulls.requestedReviewers(of: 1347, in: "octocat", "Hello-World")
        #expect(requests.users.count == 1)
        _ = try await pulls.requestReviewers(["mona"], teams: ["core"], on: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.requestReviewers(teams: ["core"], on: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.removeRequestedReviewers([], teams: ["core"], from: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.rerequestReviewers(["mona"], on: 1347, in: "octocat", "Hello-World")
        let base = "/repos/octocat/Hello-World/pulls/1347/requested_reviewers"
        #expect(
            transport.requests.map(\.route) == ["GET \(base)", "POST \(base)", "POST \(base)", "DELETE \(base)", "POST \(base)/rerequest"])
        #expect(transport.requests[1].jsonBody == ["reviewers": ["mona"], "team_reviewers": ["core"]])
        #expect(transport.requests[2].jsonBody == ["team_reviewers": ["core"]])
        #expect(transport.requests[3].jsonBody == ["reviewers": [], "team_reviewers": ["core"]])
        #expect(transport.requests[4].jsonBody == ["reviewers": ["mona"]])
    }

    @Test func reviews() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", let path) where path.hasSuffix("/reviews"): .fixture("pull-request-review-items")
            case ("GET", let path) where path.hasSuffix("/comments"): .fixture("review-comment-items")
            case ("PUT", let path) where path.hasSuffix("/dismissals"): .fixture("pull-request-review-3")
            default: .fixture("pull-request-review")
            }
        }
        let pulls = makeClient(transport).pullRequests
        _ = try await pulls.reviews(of: 1347, in: "octocat", "Hello-World").collect()
        _ = try await pulls.review(id: 80, of: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.createReview(
            NewReview(
                body: "Looks good", event: .approve, commitID: "ecdd80b",
                comments: [
                    NewReviewComment("Typo", path: "README.md", at: .line(12)),
                    NewReviewComment("Split this", path: "main.swift", at: .lines(start: 3, end: 9, side: .left)),
                    NewReviewComment("Whole file", path: "LICENSE", at: .file),
                    NewReviewComment("Old style", path: "old.swift", at: .position(4)),
                ]),
            on: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.createReview(NewReview(), on: 1347, in: "octocat", "Hello-World")
        _ = try await pulls.submitReview(id: 80, of: 1347, in: "octocat", "Hello-World", event: .requestChanges, body: "Please fix")
        _ = try await pulls.updateReview(id: 80, of: 1347, in: "octocat", "Hello-World", body: "Updated")
        _ = try await pulls.deletePendingReview(id: 80, of: 1347, in: "octocat", "Hello-World")
        let dismissed = try await pulls.dismissReview(id: 80, of: 1347, in: "octocat", "Hello-World", message: "Stale")
        #expect(dismissed.state == .dismissed)
        _ = try await pulls.comments(inReview: 80, of: 1347, in: "octocat", "Hello-World").collect()
        let base = "/repos/octocat/Hello-World/pulls/1347/reviews"
        #expect(
            transport.requests.map(\.route) == [
                "GET \(base)", "GET \(base)/80", "POST \(base)", "POST \(base)", "POST \(base)/80/events", "PUT \(base)/80",
                "DELETE \(base)/80", "PUT \(base)/80/dismissals", "GET \(base)/80/comments",
            ])
        #expect(
            transport.requests[2].jsonBody == [
                "body": "Looks good", "event": "APPROVE", "commit_id": "ecdd80b",
                "comments": [
                    ["body": "Typo", "path": "README.md", "line": 12, "side": "RIGHT"],
                    ["body": "Split this", "path": "main.swift", "start_line": 3, "start_side": "RIGHT", "line": 9, "side": "LEFT"],
                    ["body": "Whole file", "path": "LICENSE", "subject_type": "file"],
                    ["body": "Old style", "path": "old.swift", "position": 4],
                ],
            ])
        #expect(transport.requests[3].jsonBody == [:])
        #expect(transport.requests[4].jsonBody == ["event": "REQUEST_CHANGES", "body": "Please fix"])
        #expect(transport.requests[5].jsonBody == ["body": "Updated"])
        #expect(transport.requests[7].jsonBody == ["message": "Stale", "event": "DISMISS"])
    }

    @Test func reviewComments() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "DELETE": .noContent()
            case "GET" where request.path.hasSuffix("comments"): .fixture("pull-request-review-comment-items")
            default: .fixture("pull-request-review-comment")
            }
        }
        let pulls = makeClient(transport).pullRequests
        let since = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await pulls.reviewComments(on: 1347, in: "octocat", "Hello-World", sort: .updated, updatedSince: since).collect()
        _ = try await pulls.reviewComments("octocat", "Hello-World").collect()
        _ = try await pulls.reviewComment(id: 10, in: "octocat", "Hello-World")
        _ = try await pulls.createReviewComment(
            NewReviewComment("Nit", path: "file1.txt", at: .line(2, side: .left), commitID: "6dcb09b"), on: 1347, in: "octocat",
            "Hello-World")
        _ = try await pulls.replyToReviewComment(id: 10, on: 1347, in: "octocat", "Hello-World", body: "Done")
        _ = try await pulls.updateReviewComment(id: 10, in: "octocat", "Hello-World", body: "Edited")
        try await pulls.deleteReviewComment(id: 10, in: "octocat", "Hello-World")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/Hello-World/pulls/1347/comments", "GET /repos/octocat/Hello-World/pulls/comments",
                "GET /repos/octocat/Hello-World/pulls/comments/10", "POST /repos/octocat/Hello-World/pulls/1347/comments",
                "POST /repos/octocat/Hello-World/pulls/1347/comments/10/replies", "PATCH /repos/octocat/Hello-World/pulls/comments/10",
                "DELETE /repos/octocat/Hello-World/pulls/comments/10",
            ])
        #expect(transport.requests[0].queryItems == ["since": "2023-11-14T22:13:20Z", "sort": "updated", "per_page": "100"])
        #expect(transport.requests[1].queryItems == ["per_page": "100"])
        #expect(
            transport.requests[3].jsonBody == ["body": "Nit", "path": "file1.txt", "line": 2, "side": "LEFT", "commit_id": "6dcb09b"])
        #expect(transport.requests[4].jsonBody == ["body": "Done"])
    }

    // MARK: Stacks and timeline

    @Test func stacks() async throws {
        let transport = MockTransport { request, index in
            switch (request.httpMethod, request.path) {
            case ("GET", let path) where path.hasSuffix("/stacks"): .fixture("pull-request-stack-items")
            case ("POST", let path) where path.hasSuffix("/unstack"): index == 4 ? .fixture("pull-request-stack") : .noContent()
            default: .fixture("pull-request-stack", status: request.httpMethod == "POST" ? 201 : 200)
            }
        }
        let pulls = makeClient(transport).pullRequests
        _ = try await pulls.stacks("octocat", "hello-world", containing: 101).collect()
        _ = try await pulls.stack(42, in: "octocat", "hello-world")
        _ = try await pulls.createStack([101, 102], in: "octocat", "hello-world")
        _ = try await pulls.addToStack([103], stack: 42, in: "octocat", "hello-world")
        let remaining = try await pulls.unstack(42, in: "octocat", "hello-world")
        #expect(remaining?.number == 42)
        let gone = try await pulls.unstack(42, in: "octocat", "hello-world")
        #expect(gone == nil)
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/octocat/hello-world/stacks", "GET /repos/octocat/hello-world/stacks/42",
                "POST /repos/octocat/hello-world/stacks", "POST /repos/octocat/hello-world/stacks/42/add",
                "POST /repos/octocat/hello-world/stacks/42/unstack", "POST /repos/octocat/hello-world/stacks/42/unstack",
            ])
        #expect(transport.requests[0].queryItems == ["pull_request": "101", "per_page": "100"])
        #expect(transport.requests[2].jsonBody == ["pull_requests": [101, 102]])
        #expect(transport.requests[3].jsonBody == ["pull_requests": [103]])
    }

    @Test func timeline() async throws {
        let transport = MockTransport(.fixture("timeline-issue-events"))
        let issues = makeClient(transport).issues
        let entries = try await issues.timeline(of: 1347, in: "octocat", "Hello-World", excluding: [.labeled, .renamed]).collect()
        #expect(entries.count == 4)
        #expect(transport.requests.map(\.route) == ["GET /repos/octocat/Hello-World/issues/1347/timeline"])
        #expect(transport.requests[0].queryItems == ["exclude": "labeled,renamed", "per_page": "100"])
    }
}
