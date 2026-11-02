import Foundation
import Testing

@testable import GHKit

@Suite("Releases")
struct ReleasesTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let release = try decoder.decode(Release.self, from: loadFixture("release"))
        #expect(release.tagName == "v1.0.0")
        #expect(release.isDraft == false)
        #expect(release.assets.first?.state == .uploaded)
        _ = try decoder.decode([Release].self, from: loadFixture("release-items"))
        let asset = try decoder.decode(ReleaseAsset.self, from: loadFixture("release-asset"))
        #expect(asset.name == "example.zip")
        _ = try decoder.decode([ReleaseAsset].self, from: loadFixture("release-asset-items"))
        _ = try decoder.decode(ReleaseAsset.self, from: loadFixture("release-asset-response-for-successful-upload"))
        let notes = try decoder.decode(ReleaseNotes.self, from: loadFixture("release-notes-content"))
        #expect(!notes.body.isEmpty)

        let reactions = try decoder.decode(
            ReactionSummary.self,
            from: Data(
                #"{"total_count":3,"+1":2,"-1":0,"laugh":0,"confused":0,"heart":1,"hooray":0,"eyes":0,"rocket":0}"#.utf8))
        #expect(reactions.thumbsUp == 2)
    }

    @Test func releaseRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /repos/o/r/releases": .fixture("release-items")
            case "POST /repos/o/r/releases/generate-notes": .fixture("release-notes-content")
            case "DELETE /repos/o/r/releases/1": .noContent()
            default: .fixture("release", status: request.httpMethod == "POST" ? 201 : 200)
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.releases("o", "r").collect()
        _ = try await repos.release(id: 1, in: "o", "r")
        _ = try await repos.latestRelease("o", "r")
        _ = try await repos.release(tag: "v1.0.0", in: "o", "r")
        _ = try await repos.createRelease(
            NewRelease(tagName: "v2.0.0", targetCommitish: "main", isDraft: true, generateReleaseNotes: true, makeLatest: .legacy),
            in: "o", "r")
        _ = try await repos.updateRelease(id: 1, in: "o", "r", ReleaseUpdate(isDraft: false))
        try await repos.deleteRelease(id: 1, in: "o", "r")
        _ = try await repos.generateReleaseNotes(for: "v2.0.0", in: "o", "r", previousTag: "v1.0.0")
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/releases", "GET /repos/o/r/releases/1", "GET /repos/o/r/releases/latest",
                "GET /repos/o/r/releases/tags/v1.0.0", "POST /repos/o/r/releases", "PATCH /repos/o/r/releases/1",
                "DELETE /repos/o/r/releases/1", "POST /repos/o/r/releases/generate-notes",
            ])
        #expect(
            transport.requests[4].jsonBody == [
                "tag_name": "v2.0.0", "target_commitish": "main", "draft": true, "generate_release_notes": true,
                "make_latest": "legacy",
            ])
        #expect(transport.requests[5].jsonBody == ["draft": false])
        #expect(transport.requests[7].jsonBody == ["tag_name": "v2.0.0", "previous_tag_name": "v1.0.0"])
    }

    @Test func assetRequests() async throws {
        let transport = MockTransport { request, _ in
            if request.value(forHTTPHeaderField: "Accept") == "application/octet-stream" {
                return MockResponse(body: Data([0x50, 0x4B]))
            }
            return switch request.route {
            case "GET /repos/o/r/releases/1/assets": .fixture("release-asset-items")
            case "DELETE /repos/o/r/releases/assets/2": .noContent()
            default: .fixture("release-asset")
            }
        }
        let repos = makeClient(transport).repositories
        _ = try await repos.releaseAssets(of: 1, in: "o", "r").collect()
        _ = try await repos.releaseAsset(id: 2, in: "o", "r")
        let file = try await repos.downloadReleaseAsset(id: 2, in: "o", "r")
        _ = try await repos.updateReleaseAsset(id: 2, in: "o", "r", label: "macOS build")
        try await repos.deleteReleaseAsset(id: 2, in: "o", "r")
        #expect(file == Data([0x50, 0x4B]))
        #expect(
            transport.requests.map(\.route) == [
                "GET /repos/o/r/releases/1/assets", "GET /repos/o/r/releases/assets/2", "GET /repos/o/r/releases/assets/2",
                "PATCH /repos/o/r/releases/assets/2", "DELETE /repos/o/r/releases/assets/2",
            ])
        #expect(transport.requests[3].jsonBody == ["label": "macOS build"])
    }

    @Test func uploadsGoToTheUploadsHost() async throws {
        let transport = MockTransport(.fixture("release-asset-response-for-successful-upload", status: 201))
        let repos = makeClient(transport).repositories
        let release = try decoder.decode(Release.self, from: loadFixture("release"))
        let bytes = Data("zip".utf8)
        _ = try await repos.uploadReleaseAsset(bytes, fileName: "app 1.zip", label: "App", contentType: "application/zip", to: release)
        _ = try await repos.uploadReleaseAsset(bytes, fileName: "app.zip", toRelease: 7, in: "o", "r")

        let first = transport.requests[0]
        #expect(first.httpMethod == "POST")
        #expect(first.url?.host() == "uploads.github.com")
        #expect(first.path == "/repos/octocat/Hello-World/releases/1/assets")
        #expect(first.queryItems == ["name": "app 1.zip", "label": "App"])
        #expect(first.value(forHTTPHeaderField: "Content-Type") == "application/zip")
        #expect(first.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(first.httpBody == bytes)
        #expect(transport.requests[1].url?.absoluteString == "https://uploads.github.com/repos/o/r/releases/7/assets?name=app.zip")
        #expect(transport.requests[1].value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test func uploadsURLFollowsTheServer() {
        #expect(GitHubServer.dotCom.uploadsURL.absoluteString == "https://uploads.github.com")
        let ghes = GitHubServer.enterpriseServer(URL(string: "https://ghe.example.com")!)
        #expect(ghes.uploadsURL.absoluteString == "https://ghe.example.com/api/uploads")
        #expect(GitHubServer.enterpriseCloud(subdomain: "acme").uploadsURL.absoluteString == "https://uploads.acme.ghe.com")
        let custom = GitHubServer(
            apiURL: URL(string: "https://api.example.com")!, graphQLURL: URL(string: "https://api.example.com/graphql")!,
            webURL: URL(string: "https://example.com")!)
        #expect(custom.uploadsURL.absoluteString == "https://uploads.example.com")
        let proxy = GitHubServer(
            apiURL: URL(string: "https://proxy.example.com/github")!, graphQLURL: URL(string: "https://proxy.example.com/graphql")!,
            webURL: URL(string: "https://git.example.com")!)
        #expect(proxy.uploadsURL.absoluteString == "https://git.example.com/api/uploads")
    }

    @Test func redirectsToOtherHostsDropCredentials() {
        var original = URLRequest(url: URL(string: "https://api.github.com/repos/o/r/releases/assets/1")!)
        original.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        var storage = URLRequest(url: URL(string: "https://release-assets.githubusercontent.com/file?sig=x")!)
        storage.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        #expect(RedirectPolicy.follow(storage, from: original).value(forHTTPHeaderField: "Authorization") == nil)

        var sameHost = URLRequest(url: URL(string: "https://API.github.com/repositories/1/releases/assets/1")!)
        sameHost.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        #expect(RedirectPolicy.follow(sameHost, from: original).value(forHTTPHeaderField: "Authorization") == "Bearer secret")
    }
}
