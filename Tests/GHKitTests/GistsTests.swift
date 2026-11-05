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

@Suite("Gists")
struct GistsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func gistModelsDecode() throws {
        let gist = try decoder.decode(Gist.self, from: loadFixture("gist"))
        #expect(gist.id == "2decf6c462d9b4418f2")
        #expect(gist.files["README.md"]?.content == "Hello world from GitHub")
        #expect(gist.files["README.md"]?.isTruncated == false)
        #expect(gist.isPublic)
        #expect(gist.owner?.login == "monalisa")
        #expect(gist.history?.first?.version == "468aac8caed5f0c3b859b8286968")
        #expect(gist.history?.first?.changeStatus?.total == 2)
        #expect(gist.forkOf == nil)

        let items = try decoder.decode([Gist].self, from: loadFixture("base-gist-items"))
        #expect(items.first?.files["hello_world.rb"]?.language == "Ruby")
        #expect(items.first?.files["hello_world.rb"]?.content == nil)
        _ = try decoder.decode(Gist.self, from: loadFixture("base-gist"))
        _ = try decoder.decode([Gist].self, from: loadFixture("gist-fork-items"))
        _ = try decoder.decode(Gist.self, from: loadFixture("delete-gist-file"))
        _ = try decoder.decode(Gist.self, from: loadFixture("rename-gist-file"))

        let comment = try decoder.decode(GistComment.self, from: loadFixture("gist-comment"))
        #expect(comment.body == "Just commenting for the sake of commenting")
        #expect(comment.authorAssociation == .collaborator)
        _ = try decoder.decode([GistComment].self, from: loadFixture("gist-comment-items"))

        let commits = try decoder.decode([GistCommit].self, from: loadFixture("gist-commit-items"))
        #expect(commits.first?.changeStatus?.additions == 180)
    }

    @Test func deletedFilesAndForksDecode() throws {
        let gist = try decoder.decode(
            Gist.self,
            from: Data(
                #"""
                {"id": "b", "public": false, "files": {"kept.txt": {"filename": "kept.txt"}, "gone.txt": null},
                 "fork_of": {"id": "a", "public": true, "files": {}}}
                """#.utf8))
        #expect(Array(gist.files.keys) == ["kept.txt"])
        #expect(gist.forkOf?.id == "a")
        let again = try decoder.decode(Gist.self, from: GitHubJSON.encoder().encode(gist))
        #expect(again == gist)
    }

    // MARK: Gists

    @Test func listsEachCollection() async throws {
        let transport = MockTransport(.fixture("base-gist-items"))
        let gists = makeClient(transport).gists
        _ = try await gists.list().collect()
        _ = try await gists.list(.user("octocat"), since: Date(timeIntervalSince1970: 1_700_000_000)).collect()
        _ = try await gists.list(.public, perPage: 10).collect()
        _ = try await gists.list(.starred).collect()
        #expect(transport.requests.map(\.path) == ["/gists", "/users/octocat/gists", "/gists/public", "/gists/starred"])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[1].queryItems == ["since": "2023-11-14T22:13:20Z", "per_page": "100"])
        #expect(transport.requests[2].queryItems == ["per_page": "10"])
    }

    @Test func fetchesGistsAndRevisions() async throws {
        let transport = MockTransport(.fixture("gist"))
        let gists = makeClient(transport).gists
        _ = try await gists.gist(id: "2decf6c462d9b4418f2")
        _ = try await gists.gist(id: "2decf6c462d9b4418f2", revision: "468aac8caed5f0c3b859b8286968")
        #expect(
            transport.requests.map(\.route) == [
                "GET /gists/2decf6c462d9b4418f2", "GET /gists/2decf6c462d9b4418f2/468aac8caed5f0c3b859b8286968",
            ])
    }

    @Test func createsUpdatesAndDeletes() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "POST": .fixture("gist", status: 201)
            case "PATCH": .fixture("rename-gist-file")
            default: .noContent()
            }
        }
        let gists = makeClient(transport).gists
        let gist = try await gists.create(NewGist(description: "Example", files: ["hello.rb": "puts 1"], isPublic: false))
        #expect(gist.id == "2decf6c462d9b4418f2")
        try await gists.update(
            id: "aa5a", GistUpdate(description: "New", files: ["a.rb": .content("x"), "b.rb": .rename(to: "c.rb"), "d.rb": .delete]))
        try await gists.update(id: "aa5a", GistUpdate(files: ["e.rb": .rename(to: "f.rb", content: "y")]))
        try await gists.delete(id: "aa5a")

        #expect(transport.requests[0].route == "POST /gists")
        #expect(
            transport.requests[0].jsonBody == [
                "description": "Example", "files": ["hello.rb": ["content": "puts 1"]], "public": false,
            ])
        #expect(transport.requests[1].route == "PATCH /gists/aa5a")
        #expect(
            transport.requests[1].jsonBody == [
                "description": "New", "files": ["a.rb": ["content": "x"], "b.rb": ["filename": "c.rb"], "d.rb": nil],
            ])
        #expect(transport.requests[2].jsonBody == ["files": ["e.rb": ["filename": "f.rb", "content": "y"]]])
        #expect(transport.requests[3].route == "DELETE /gists/aa5a")
    }

    @Test func listsCommitsAndForks() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.url!.lastPathComponent) {
            case ("POST", _): .fixture("base-gist", status: 201)
            case (_, "commits"): .fixture("gist-commit-items")
            default: .fixture("gist-fork-items")
            }
        }
        let gists = makeClient(transport).gists
        let commits = try await gists.commits(of: "aa5a").collect()
        #expect(commits.first?.version == "57a7f021a713b1c5a6a199b54cc514735d2d462f")
        _ = try await gists.forks(of: "aa5a").collect()
        _ = try await gists.fork(id: "aa5a")
        #expect(transport.requests.map(\.route) == ["GET /gists/aa5a/commits", "GET /gists/aa5a/forks", "POST /gists/aa5a/forks"])
    }

    @Test func starsAndUnstars() async throws {
        let transport = MockTransport { _, index in index == 1 ? .json(#"{"message": "Not Found"}"#, status: 404) : .noContent() }
        let gists = makeClient(transport).gists
        #expect(try await gists.isStarred(id: "aa5a"))
        #expect(try await !gists.isStarred(id: "aa5a"))
        try await gists.star(id: "aa5a")
        try await gists.unstar(id: "aa5a")
        #expect(
            transport.requests.map(\.route) == [
                "GET /gists/aa5a/star", "GET /gists/aa5a/star", "PUT /gists/aa5a/star", "DELETE /gists/aa5a/star",
            ])
    }

    // MARK: Comments

    @Test func managesComments() async throws {
        let transport = MockTransport { request, _ in
            switch request.httpMethod {
            case "GET" where request.url!.lastPathComponent == "comments": .fixture("gist-comment-items")
            case "DELETE": .noContent()
            case "POST": .fixture("gist-comment", status: 201)
            default: .fixture("gist-comment")
            }
        }
        let gists = makeClient(transport).gists
        _ = try await gists.comments(on: "aa5a").collect()
        let comment = try await gists.comment(id: 1, on: "aa5a")
        #expect(comment.id == 1)
        try await gists.createComment("Hi", on: "aa5a")
        try await gists.updateComment(id: 1, on: "aa5a", body: "Edited")
        try await gists.deleteComment(id: 1, on: "aa5a")
        #expect(
            transport.requests.map(\.route) == [
                "GET /gists/aa5a/comments", "GET /gists/aa5a/comments/1", "POST /gists/aa5a/comments",
                "PATCH /gists/aa5a/comments/1", "DELETE /gists/aa5a/comments/1",
            ])
        #expect(transport.requests[2].jsonBody == ["body": "Hi"])
        #expect(transport.requests[3].jsonBody == ["body": "Edited"])
    }
}
