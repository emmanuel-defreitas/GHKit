import Foundation
import Testing

@testable import GHKitCore
@testable import GHKitRepositories

@Suite("Git database")
struct GitDatabaseTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let blob = try decoder.decode(GitBlob.self, from: loadFixture("blob"))
        #expect(blob.data == Data("Content of the blob".utf8))
        #expect(blob.size == 19)
        _ = try decoder.decode(GitCommit.Pointer.self, from: loadFixture("short-blob"))

        let commit = try decoder.decode(GitCommit.self, from: loadFixture("git-commit"))
        #expect(commit.parents.count == 1)
        _ = try decoder.decode(GitCommit.self, from: loadFixture("git-commit-2"))

        let ref = try decoder.decode(GitReference.self, from: loadFixture("git-ref"))
        #expect(ref.ref == "refs/heads/featureA")
        #expect(ref.object.type == .commit)
        #expect(try decoder.decode([GitReference].self, from: loadFixture("git-ref-items")).count == 2)

        let tag = try decoder.decode(GitTag.self, from: loadFixture("git-tag"))
        #expect(tag.tag == "v0.0.1")
        #expect(tag.tagger.date != nil)
        #expect(tag.verification?.verified == false)

        let tree = try decoder.decode(GitTree.self, from: loadFixture("git-tree"))
        #expect(tree.entries.first?.mode == .file)
        let listing = try decoder.decode(GitTree.self, from: loadFixture("git-tree-default-response"))
        #expect(listing.entries.contains { $0.type == .tree })
        #expect(!listing.truncated)
        _ = try decoder.decode(GitTree.self, from: loadFixture("git-tree-response-recursively-retrieving-a-tree"))
    }

    @Test func objectRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "POST /repos/o/r/git/blobs": .fixture("short-blob", status: 201)
            case "GET /repos/o/r/git/blobs/abc": .fixture("blob")
            case "POST /repos/o/r/git/trees": .fixture("git-tree", status: 201)
            case "POST /repos/o/r/git/commits": .fixture("git-commit", status: 201)
            case "GET /repos/o/r/git/commits/abc": .fixture("git-commit-2")
            case "POST /repos/o/r/git/tags": .fixture("git-tag", status: 201)
            case "GET /repos/o/r/git/tags/abc": .fixture("git-tag")
            default: .fixture("git-tree-default-response")
            }
        }
        let git = makeClient(transport).repositories.git("o", "r")
        _ = try await git.createBlob(Data("hi".utf8))
        _ = try await git.createBlob(text: "hi")
        _ = try await git.blob("abc")
        _ = try await git.tree("main")
        _ = try await git.tree("release/v1", recursive: true)
        _ = try await git.createTree(
            [.file("README.md", content: "Hello"), .blob("run.sh", sha: "b1", mode: .executable), .tree("docs", sha: "t1"), .delete("old.txt")],
            base: "base")
        _ = try await git.createTree([.file("a.txt", content: "a")])
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await git.createCommit(
            NewGitCommit(message: "Update", tree: "t2", parents: ["p1"], author: GitActor(name: "Mona", email: "mona@example.com", date: when)))
        _ = try await git.commit("abc")
        _ = try await git.createTag(NewGitTag("v1.0", message: "First", object: "c1"))
        _ = try await git.tag("abc")

        #expect(
            transport.requests.map(\.route) == [
                "POST /repos/o/r/git/blobs", "POST /repos/o/r/git/blobs", "GET /repos/o/r/git/blobs/abc", "GET /repos/o/r/git/trees/main",
                "GET /repos/o/r/git/trees/release/v1", "POST /repos/o/r/git/trees", "POST /repos/o/r/git/trees",
                "POST /repos/o/r/git/commits", "GET /repos/o/r/git/commits/abc", "POST /repos/o/r/git/tags", "GET /repos/o/r/git/tags/abc",
            ])
        #expect(transport.requests[0].jsonBody == ["content": "aGk=", "encoding": "base64"])
        #expect(transport.requests[1].jsonBody == ["content": "hi", "encoding": "utf-8"])
        #expect(transport.requests[3].queryItems == [:])
        #expect(transport.requests[4].queryItems == ["recursive": "1"])
        #expect(
            transport.requests[5].jsonBody == [
                "base_tree": "base",
                "tree": [
                    ["path": "README.md", "mode": "100644", "type": "blob", "content": "Hello"],
                    ["path": "run.sh", "mode": "100755", "type": "blob", "sha": "b1"],
                    ["path": "docs", "mode": "040000", "type": "tree", "sha": "t1"],
                    ["path": "old.txt", "mode": "100644", "type": "blob", "sha": nil],
                ],
            ])
        #expect(transport.requests[6].jsonBody == ["tree": [["path": "a.txt", "mode": "100644", "type": "blob", "content": "a"]]])
        #expect(
            transport.requests[7].jsonBody == [
                "message": "Update", "tree": "t2", "parents": ["p1"],
                "author": ["name": "Mona", "email": "mona@example.com", "date": "2023-11-14T22:13:20Z"],
            ])
        #expect(transport.requests[9].jsonBody == ["tag": "v1.0", "message": "First", "object": "c1", "type": "commit"])
    }

    @Test func referenceRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case let route where route.hasPrefix("GET /repos/o/r/git/matching-refs/"): .fixture("git-ref-items")
            case "DELETE /repos/o/r/git/refs/heads/feature/x": .noContent()
            case "POST /repos/o/r/git/refs": .fixture("git-ref", status: 201)
            default: .fixture("git-ref")
            }
        }
        let git = makeClient(transport).repositories.git("o", "r")
        _ = try await git.ref("heads/main")
        _ = try await git.ref("refs/tags/v1.0")
        #expect(try await git.matchingRefs("tags/v1").collect().count == 2)
        _ = try await git.createRef("refs/heads/feature/x", at: "c1")
        _ = try await git.createRef("heads/feature/y", at: "c1")
        _ = try await git.updateRef("heads/feature/x", to: "c2")
        _ = try await git.updateRef("refs/heads/feature/x", to: "c3", force: true)
        try await git.deleteRef("heads/feature/x")

        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/git/ref/heads/main", "GET /repos/o/r/git/ref/tags/v1.0", "GET /repos/o/r/git/matching-refs/tags/v1",
                "POST /repos/o/r/git/refs", "POST /repos/o/r/git/refs", "PATCH /repos/o/r/git/refs/heads/feature/x",
                "PATCH /repos/o/r/git/refs/heads/feature/x", "DELETE /repos/o/r/git/refs/heads/feature/x",
            ])
        #expect(transport.requests[3].jsonBody == ["ref": "refs/heads/feature/x", "sha": "c1"])
        #expect(transport.requests[4].jsonBody == ["ref": "refs/heads/feature/y", "sha": "c1"])
        #expect(transport.requests[5].jsonBody == ["sha": "c2", "force": false])
        #expect(transport.requests[6].jsonBody == ["sha": "c3", "force": true])
    }
}
