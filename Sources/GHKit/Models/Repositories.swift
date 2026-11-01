import Foundation

/// A repository as it appears in lists and inside other objects (`minimal-repository`).
public struct MinimalRepository: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var name: String
    /// `owner/name`.
    public var fullName: String
    public var owner: SimpleUser
    public var isPrivate: Bool
    public var htmlURL: URL?
    public var url: URL?
    public var description: String?
    public var homepage: String?
    public var language: String?
    public var isFork: Bool?
    public var isTemplate: Bool?
    public var isArchived: Bool?
    public var isDisabled: Bool?
    /// `public`, `private`, or `internal`.
    public var visibility: String?
    public var defaultBranch: String?
    public var topics: [String]?
    public var forksCount: Int?
    public var stargazersCount: Int?
    public var watchersCount: Int?
    public var openIssuesCount: Int?
    /// Size in kilobytes.
    public var size: Int?
    public var hasIssues: Bool?
    public var hasProjects: Bool?
    public var hasWiki: Bool?
    public var hasPages: Bool?
    public var hasDiscussions: Bool?
    public var cloneURL: URL?
    public var sshURL: String?
    public var pushedAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, url, description, homepage, language, visibility, topics, size
        case nodeID = "node_id"
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
        case isFork = "fork"
        case isTemplate = "is_template"
        case isArchived = "archived"
        case isDisabled = "disabled"
        case defaultBranch = "default_branch"
        case forksCount = "forks_count"
        case stargazersCount = "stargazers_count"
        case watchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case hasIssues = "has_issues"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case hasDiscussions = "has_discussions"
        case cloneURL = "clone_url"
        case sshURL = "ssh_url"
        case pushedAt = "pushed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
