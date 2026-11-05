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

@Suite("Repository contents")
struct ContentsTests {
    let decoder = GitHubJSON.decoder()

    // MARK: Models

    @Test func contentsDecodeEveryShape() throws {
        let file = try decoder.decode(Contents.self, from: loadFixture("content-file"))
        #expect(file.item?.type == .file)
        #expect(file.item?.name == "README.md")

        let directory = try decoder.decode(Contents.self, from: loadFixture("content-directory"))
        #expect(directory.entries?.isEmpty == false)
        #expect(directory.entries?.contains { $0.type == .directory } == true)

        let symlink = try decoder.decode(Contents.self, from: loadFixture("content-symlink"))
        #expect(symlink.item?.target != nil)

        let submodule = try decoder.decode(Contents.self, from: loadFixture("content-submodule"))
        #expect(submodule.item?.submoduleGitURL != nil)
    }

    @Test func fileContentDecodesBase64WithLineBreaks() throws {
        let json = #"{"type":"file","name":"a.txt","path":"a.txt","sha":"1","size":11,"encoding":"base64","content":"aGVsbG8g\nd29ybGQ=\n"}"#
        let file = try decoder.decode(RepositoryContent.self, from: Data(json.utf8))
        #expect(file.text == "hello world")
    }

    @Test func otherModelsDecode() throws {
        let commit = try decoder.decode(FileCommit.self, from: loadFixture("file-commit"))
        #expect(commit.commit.message == "my commit message")
        #expect(commit.commit.author.name == "Monalisa Octocat")
        #expect(commit.commit.parents.count == 1)
        #expect(commit.content?.path == "notes/hello.txt")

        let license = try decoder.decode(RepositoryLicense.self, from: loadFixture("license-content"))
        #expect(license.license?.spdxID == "MIT")
        #expect(license.file.name == "LICENSE")

        let merged = try decoder.decode(MergeUpstreamResult.self, from: loadFixture("merged-upstream"))
        #expect(merged.mergeType == "fast-forward")
    }

    // MARK: Requests

    @Test func readingContents() async throws {
        let transport = MockTransport { request, _ in
            request.value(forHTTPHeaderField: "Accept") == "application/vnd.github.raw+json"
                ? MockResponse(body: Data("raw bytes".utf8)) : .fixture("content-file")
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.contents("o", "r", at: "Sources/My App/main.swift", ref: "dev")
        _ = try await repos.contents("o", "r")
        let raw = try await repos.rawContents("o", "r", at: "big.bin")
        _ = try await repos.readme("o", "r")
        _ = try await repos.readme("o", "r", in: "docs/guide", ref: "v1")
        #expect(raw == Data("raw bytes".utf8))
        #expect(transport.requests[0].url?.path(percentEncoded: true) == "/repos/o/r/contents/Sources/My%20App/main.swift")
        #expect(transport.requests[0].queryItems == ["ref": "dev"])
        #expect(transport.requests[1].path == "/repos/o/r/contents/")
        #expect(transport.requests[3].path == "/repos/o/r/readme")
        #expect(transport.requests[4].path == "/repos/o/r/readme/docs/guide")
    }

    @Test func writingFiles() async throws {
        let transport = MockTransport(.fixture("file-commit", status: 201))
        let repos = makeClient(transport).repositories
        let mona = GitActor(name: "Mona", email: "mona@example.com")
        _ = try await repos.writeFile(
            FileChange(message: "Add notes", text: "hello", replacing: "abc", branch: "main", committer: mona),
            to: "notes/hello.txt", in: "o", "r")
        _ = try await repos.deleteFile("notes/hello.txt", sha: "def", message: "Remove notes", in: "o", "r")
        #expect(transport.requests[0].httpMethod == "PUT")
        #expect(transport.requests[0].path == "/repos/o/r/contents/notes/hello.txt")
        #expect(
            transport.requests[0].jsonBody == [
                "message": "Add notes", "content": "aGVsbG8=", "sha": "abc", "branch": "main",
                "committer": ["name": "Mona", "email": "mona@example.com"],
            ])
        #expect(transport.requests[1].httpMethod == "DELETE")
        #expect(transport.requests[1].jsonBody == ["message": "Remove notes", "sha": "def"])
    }

    @Test func archivesLicenseAndCodeowners() async throws {
        let transport = MockTransport { request, _ in
            switch request.path {
            case "/repos/o/r/license": .fixture("license-content")
            case "/repos/o/r/codeowners/errors": .fixture("codeowners-errors")
            default: MockResponse(body: Data([0x50, 0x4B]))
            }
        }
        let repos = makeClient(transport).repositories
        let zip = try await repos.archive("o", "r")
        _ = try await repos.archive("o", "r", format: .tarball, ref: "v1.0")
        _ = try await repos.license("o", "r")
        let errors = try await repos.codeownersErrors("o", "r", ref: "main")
        #expect(zip == Data([0x50, 0x4B]))
        #expect(errors.count == 2)
        #expect(errors.first?.suggestion == "Did you mean `**/*.rb`?")
        #expect(transport.requests[0].path == "/repos/o/r/zipball")
        #expect(transport.requests[1].path == "/repos/o/r/tarball/v1.0")
    }

    @Test func forksAndTemplates() async throws {
        let transport = MockTransport { request, _ in
            switch (request.httpMethod, request.path) {
            case ("GET", _): .fixture("fork-items")
            case (_, "/repos/o/r/merge-upstream"): .fixture("merged-upstream")
            default: .fixture("full-repository", status: 202)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.forks("o", "r", sort: .stargazers).collect()
        _ = try await repos.fork("o", "r", into: "acme", as: "r2", defaultBranchOnly: true)
        _ = try await repos.syncWithUpstream("o", "r", branch: "main")
        _ = try await repos.create(NewRepositoryFromTemplate(name: "app", owner: "acme", isPrivate: true), fromTemplate: "o", "template")
        #expect(transport.requests[0].queryItems == ["sort": "stargazers", "per_page": "100"])
        #expect(transport.requests[1].jsonBody == ["organization": "acme", "name": "r2", "default_branch_only": true])
        #expect(transport.requests[2].jsonBody == ["branch": "main"])
        #expect(transport.requests[3].path == "/repos/o/template/generate")
        #expect(transport.requests[3].jsonBody == ["name": "app", "owner": "acme", "private": true])
    }
}
