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
    static let everyToolset: [GitHubToolset] = [
        .context, .users, .repositories, .issues, .pullRequests, .search, .activity, .gists, .reactions, .organizations, .teams,
        .projects, .rawRequests,
    ]
}

extension GitHubToolset {
    /// The signed-in user and the current rate limits.
    public static let context = GitHubToolset("context", tools: ContextTools.tools)

    /// User profiles, followers, and following.
    public static let users = GitHubToolset("users", tools: UserTools.tools)

    /// Repositories, files, branches, commits, tags, and releases.
    public static let repositories = GitHubToolset("repositories", tools: RepositoryTools.tools)

    /// Issues and their comments, timelines, labels, assignees, milestones, and sub-issues.
    public static let issues = GitHubToolset("issues", tools: IssueTools.tools)

    /// Pull requests, their diffs and files, reviews, review comments, and merging.
    public static let pullRequests = GitHubToolset("pull_requests", tools: PullRequestTools.tools)

    /// Search code, issues and pull requests, repositories, users, and commits.
    public static let search = GitHubToolset("search", tools: SearchTools.tools)

    /// Notifications, events, stars, and watching.
    public static let activity = GitHubToolset("activity", tools: ActivityTools.tools)

    /// Gists: list, read, create, update, and delete.
    public static let gists = GitHubToolset("gists", tools: GistTools.tools)

    /// Emoji reactions on issues, pull requests, comments, and releases.
    public static let reactions = GitHubToolset("reactions", tools: ReactionTools.tools)

    /// Organizations, their members, outside collaborators, and invitations.
    public static let organizations = GitHubToolset("organizations", tools: OrganizationTools.tools)

    /// Teams, their members and child teams, and their repository access.
    public static let teams = GitHubToolset("teams", tools: TeamTools.tools)

    /// Projects, their fields and items, and status updates.
    public static let projects = GitHubToolset("projects", tools: ProjectTools.tools)

    /// `github_rest` and `github_graphql`, for anything the other toolsets don't cover.
    ///
    /// With ``GitHubToolAccess/readOnly``, `github_rest` only sends `GET` requests and
    /// `github_graphql` refuses mutations.
    public static let rawRequests = GitHubToolset("raw_requests", tools: RawRequestTools.tools)
}

extension Set where Element == GitHubToolset {
    /// The toolsets most assistants need.
    public static var defaults: Set<GitHubToolset> { [.context, .repositories, .issues, .pullRequests, .search] }

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
