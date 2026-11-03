/// A group of related GitHub tools, such as everything for issues.
///
/// Pick the toolsets an assistant needs. Fewer tools make it easier for a model to choose well.
///
///     let toolbox = GitHubToolbox(client: github, toolsets: [.context, .repositories])
public struct GitHubToolset: Sendable, Hashable, CustomStringConvertible {
    /// A stable identifier, such as `issues`. Use it to read toolsets from configuration.
    public let name: String
    let makeTools: @Sendable (GitHubToolAccess) -> [GitHubTool]

    init(_ name: String, tools: @escaping @Sendable (GitHubToolAccess) -> [GitHubTool]) {
        self.name = name
        self.makeTools = tools
    }

    public var description: String { name }

    public static func == (lhs: GitHubToolset, rhs: GitHubToolset) -> Bool { lhs.name == rhs.name }
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }

    /// The toolset with this ``name``, or `nil` if there isn't one.
    public static func named(_ name: String) -> GitHubToolset? {
        everyToolset.first { $0.name == name }
    }

    /// Every toolset, in the order their tools are listed.
    static let everyToolset: [GitHubToolset] = [.context, .repositories, .rawRequests]
}

extension GitHubToolset {
    /// The signed-in user and the current rate limits.
    public static let context = GitHubToolset("context", tools: ContextTools.tools)

    /// Repositories, files, branches, commits, tags, and releases.
    public static let repositories = GitHubToolset("repositories", tools: RepositoryTools.tools)

    /// `github_rest` and `github_graphql`, for anything the other toolsets don't cover.
    ///
    /// With ``GitHubToolAccess/readOnly``, `github_rest` only sends `GET` requests and
    /// `github_graphql` refuses mutations.
    public static let rawRequests = GitHubToolset("raw_requests", tools: RawRequestTools.tools)
}

extension Set where Element == GitHubToolset {
    /// The toolsets most assistants need.
    public static var defaults: Set<GitHubToolset> { [.context, .repositories] }

    /// Every toolset.
    public static var all: Set<GitHubToolset> { Set(GitHubToolset.everyToolset) }
}

/// Whether tools may change anything on GitHub.
public enum GitHubToolAccess: Sendable, Hashable {
    /// Only tools that read. Tools that create, change, or delete aren't listed.
    case readOnly
    /// Every tool, including ones that create, change, or delete.
    case readWrite
}
