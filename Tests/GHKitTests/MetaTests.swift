import Foundation
import Testing

@testable import GHKitCore
@testable import GHKitMeta

@Suite("Meta")
struct MetaTests {
    let decoder = GitHubJSON.decoder()

    @Test func modelsDecode() throws {
        let root = try decoder.decode(APIRoot.self, from: loadFixture("root"))
        #expect(root["user_url"] == "https://api.github.com/users/{user}")

        let meta = try decoder.decode(GitHubMeta.self, from: loadFixture("api-overview"))
        #expect(meta.verifiablePasswordAuthentication)
        #expect(meta.sshKeyFingerprints?["SHA256_ED25519"] != nil)
        #expect(meta.domains?.website == ["*.example.com"])

        let license = try decoder.decode(License.self, from: loadFixture("license"))
        #expect(license.spdxID == "MIT")
        #expect(license.permissions.contains("commercial-use"))
        #expect(try decoder.decode([LicenseSummary].self, from: loadFixture("license-simple-items")).isEmpty == false)

        let template = try decoder.decode(GitignoreTemplate.self, from: loadFixture("gitignore-template"))
        #expect(template.name == "C")

        let conduct = try decoder.decode(CodeOfConduct.self, from: loadFixture("code-of-conduct"))
        #expect(conduct.key == "contributor_covenant")
        #expect(conduct.body != nil)
        _ = try decoder.decode([CodeOfConductSummary].self, from: loadFixture("code-of-conduct-simple-items"))

        let emojis = try decoder.decode([String: URL].self, from: loadFixture("emojis-get"))
        #expect(emojis["+1"] != nil)
    }

    @Test func serviceRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /": .fixture("root")
            case "GET /meta": .fixture("api-overview")
            case "GET /versions": .json(#"["2022-11-28","2026-03-10"]"#)
            case "GET /emojis": .fixture("emojis-get")
            case "GET /octocat": MockResponse(body: Data("  MMM.  ".utf8))
            default: MockResponse(body: Data("Keep it logically awesome.".utf8))
            }
        }
        let meta = makeClient(transport).meta
        _ = try await meta.root()
        _ = try await meta.overview()
        #expect(try await meta.versions() == [CalendarDate(year: 2022, month: 11, day: 28), CalendarDate(year: 2026, month: 3, day: 10)])
        #expect(try await meta.zen() == "Keep it logically awesome.")
        #expect(try await meta.octocat(saying: "Hi there") == "  MMM.  ")
        _ = try await meta.octocat()
        _ = try await meta.emojis()

        #expect(
            transport.requests.map(\.route) == [
                "GET /", "GET /meta", "GET /versions", "GET /zen", "GET /octocat", "GET /octocat", "GET /emojis",
            ])
        #expect(transport.requests[3].value(forHTTPHeaderField: "Accept") == "text/plain")
        #expect(transport.requests[4].value(forHTTPHeaderField: "Accept") == "application/octocat-stream")
        #expect(transport.requests[4].queryItems == ["s": "Hi there"])
        #expect(transport.requests[5].queryItems == [:])
    }

    @Test func referenceRequests() async throws {
        let transport = MockTransport { request, _ in
            switch request.route {
            case "GET /licenses": .fixture("license-simple-items")
            case "GET /licenses/apache-2.0": .fixture("license")
            case "GET /gitignore/templates": .json(#"["C","Swift"]"#)
            case "GET /gitignore/templates/Objective-C": .fixture("gitignore-template")
            case "GET /codes_of_conduct": .fixture("code-of-conduct-simple-items")
            default: .fixture("code-of-conduct")
            }
        }
        let meta = makeClient(transport).meta
        _ = try await meta.licenses().collect()
        _ = try await meta.licenses(featured: true, perPage: 10).collect()
        _ = try await meta.license("apache-2.0")
        #expect(try await meta.gitignoreTemplates() == ["C", "Swift"])
        _ = try await meta.gitignoreTemplate("Objective-C")
        _ = try await meta.codesOfConduct()
        _ = try await meta.codeOfConduct("contributor_covenant")

        #expect(
            transport.requests.map(\.route) == [
                "GET /licenses", "GET /licenses", "GET /licenses/apache-2.0", "GET /gitignore/templates",
                "GET /gitignore/templates/Objective-C", "GET /codes_of_conduct", "GET /codes_of_conduct/contributor_covenant",
            ])
        #expect(transport.requests[0].queryItems == ["per_page": "100"])
        #expect(transport.requests[1].queryItems == ["featured": "true", "per_page": "10"])
    }

    @Test func markdownRequests() async throws {
        let transport = MockTransport(MockResponse(body: Data("<p>Hi</p>".utf8)))
        let meta = makeClient(transport).meta
        #expect(try await meta.renderMarkdown("Hi") == "<p>Hi</p>")
        _ = try await meta.renderMarkdown("Fixes #1", mode: .gfm, context: ("octocat", "Hello-World"))
        _ = try await meta.renderMarkdownRaw("# Title")

        #expect(transport.requests.map(\.route) == ["POST /markdown", "POST /markdown", "POST /markdown/raw"])
        #expect(transport.requests[0].jsonBody == ["text": "Hi", "mode": "markdown"])
        #expect(transport.requests[1].jsonBody == ["text": "Fixes #1", "mode": "gfm", "context": "octocat/Hello-World"])
        #expect(transport.requests[0].value(forHTTPHeaderField: "Accept") == "text/html")
        #expect(transport.requests[2].value(forHTTPHeaderField: "Content-Type") == "text/plain")
        #expect(transport.requests[2].httpBody.map { String(decoding: $0, as: UTF8.self) } == "# Title")
    }
}
