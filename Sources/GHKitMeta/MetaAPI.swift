import Foundation
import GHKitCore

extension GitHubClient {
    /// GitHub's utility endpoints: service information, licenses, `.gitignore` templates, codes of conduct,
    /// emojis, and Markdown rendering.
    public var meta: MetaAPI { MetaAPI(client: scoped(to: .meta)) }
}

/// GitHub's utility endpoints. Reach them with `github.meta`. None of them need a scope.
///
///     let html = try await github.meta.renderMarkdown("Fixes #42", mode: .gfm, context: ("octocat", "Hello-World"))
///     let mit = try await github.meta.license("mit")
///
/// Part of the `GHKitMeta` library.
public struct MetaAPI: Sendable {
    let client: GitHubClient

    private func text(_ method: HTTPMethod, _ path: String, accept: String, query: [URLQueryItem] = [], body: RequestBody? = nil)
        async throws(GitHubError) -> String
    {
        try await client.value(
            GitHubRequest(method: method, target: .path(path), query: query, headers: ["Accept": accept], body: body) {
                String(decoding: $0, as: UTF8.self)
            })
    }

    // MARK: Service

    /// URL templates for the API's main resources, by name, such as `user_url`. `GET /`
    public func root() async throws(GitHubError) -> APIRoot {
        try await client.value(GitHubRequest(.get, "/"))
    }

    /// GitHub's IP ranges, SSH host keys, and domains, for allow lists. `GET /meta`
    public func overview() async throws(GitHubError) -> GitHubMeta {
        try await client.value(GitHubRequest(.get, "/meta"))
    }

    /// The REST API versions the server supports, oldest first, for the `X-GitHub-Api-Version` header.
    /// `GET /versions`
    public func versions() async throws(GitHubError) -> [CalendarDate] {
        try await client.value(GitHubRequest(.get, "/versions"))
    }

    /// A random line of GitHub's design philosophy, such as "Keep it logically awesome." `GET /zen`
    public func zen() async throws(GitHubError) -> String {
        try await text(.get, "/zen", accept: "text/plain")
    }

    /// The Octocat as ASCII art, with a speech bubble. `GET /octocat`
    /// - Parameter words: What the Octocat says. Defaults to a random line from ``zen()``.
    public func octocat(saying words: String? = nil) async throws(GitHubError) -> String {
        try await text(.get, "/octocat", accept: "application/octocat-stream", query: .query(("s", words)))
    }

    /// Every emoji GitHub renders, by shortcode name (such as `+1`), with the image to show for it. `GET /emojis`
    public func emojis() async throws(GitHubError) -> [String: URL] {
        try await client.value(GitHubRequest(.get, "/emojis"))
    }

    // MARK: Licenses

    /// Commonly used open source licenses. `GET /licenses`
    /// - Parameter featured: Only the licenses GitHub features when creating a repository, or only the others.
    public func licenses(featured: Bool? = nil, perPage: Int = 100) -> Paginated<LicenseSummary> {
        client.paginate(GitHubRequest(.get, "/licenses", query: .query(("featured", featured), ("per_page", perPage))))
    }

    /// One license, with its full text. `GET /licenses/{license}`
    /// - Parameter key: Such as `mit` or `apache-2.0`.
    public func license(_ key: String) async throws(GitHubError) -> License {
        try await client.value(GitHubRequest(.get, "/licenses/\(escape(key))"))
    }

    // MARK: .gitignore templates

    /// The names of every `.gitignore` template, such as `Swift`. `GET /gitignore/templates`
    public func gitignoreTemplates() async throws(GitHubError) -> [String] {
        try await client.value(GitHubRequest(.get, "/gitignore/templates"))
    }

    /// One `.gitignore` template. `GET /gitignore/templates/{name}`
    /// - Parameter name: Such as `Swift`. Names are case-sensitive.
    public func gitignoreTemplate(_ name: String) async throws(GitHubError) -> GitignoreTemplate {
        try await client.value(GitHubRequest(.get, "/gitignore/templates/\(escape(name))"))
    }

    // MARK: Codes of conduct

    /// Every code of conduct GitHub offers when adding one to a repository. `GET /codes_of_conduct`
    public func codesOfConduct() async throws(GitHubError) -> [CodeOfConductSummary] {
        try await client.value(GitHubRequest(.get, "/codes_of_conduct"))
    }

    /// One code of conduct, with its text. `GET /codes_of_conduct/{key}`
    /// - Parameter key: Such as `contributor_covenant`.
    public func codeOfConduct(_ key: String) async throws(GitHubError) -> CodeOfConduct {
        try await client.value(GitHubRequest(.get, "/codes_of_conduct/\(escape(key))"))
    }

    // MARK: Markdown

    /// Markdown rendered as HTML, the way GitHub shows it. `POST /markdown`
    /// - Parameters:
    ///   - mode: ``MarkdownMode/gfm`` links issue references and mentions, like comments do.
    ///   - context: The repository that `#42`-style references point to in ``MarkdownMode/gfm`` mode.
    public func renderMarkdown(
        _ text: String, mode: MarkdownMode = .markdown, context: (owner: String, name: String)? = nil
    ) async throws(GitHubError) -> String {
        struct Body: Encodable, Sendable {
            let text: String
            let mode: MarkdownMode
            let context: String?
        }
        let body = Body(text: text, mode: mode, context: context.map { "\($0.owner)/\($0.name)" })
        return try await self.text(.post, "/markdown", accept: "text/html", body: .json(body))
    }

    /// Markdown rendered as HTML, sending the text as is, like a `README` file. `POST /markdown/raw`
    public func renderMarkdownRaw(_ text: String) async throws(GitHubError) -> String {
        try await self.text(.post, "/markdown/raw", accept: "text/html", body: .raw(Data(text.utf8), contentType: "text/plain"))
    }
}
