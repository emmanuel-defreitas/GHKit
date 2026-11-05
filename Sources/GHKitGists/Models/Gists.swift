import Foundation
import GHKitCore

/// A gist: a small set of files with its own Git history (`gist-simple` and `base-gist`).
public struct Gist: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var nodeID: String?
    public var url: URL?
    public var forksURL: URL?
    public var commitsURL: URL?
    public var commentsURL: URL?
    public var gitPullURL: URL?
    public var gitPushURL: URL?
    public var htmlURL: URL?
    /// The files by name. Lists leave out ``File/content``; fetch the gist on its own to read it.
    public var files: [String: File]
    public var isPublic: Bool
    public var createdAt: Date?
    public var updatedAt: Date?
    public var description: String?
    public var commentCount: Int?
    public var commentsEnabled: Bool?
    public var owner: SimpleUser?
    /// `true` when the gist has more than 300 files and ``files`` lists only the first 300.
    public var isTruncated: Bool?
    /// The gist's revisions, newest first. Only included when fetching a single gist.
    public var history: [GistCommit]?
    /// The gist this one was forked from.
    public var forkOf: Gist? {
        get { forkParent.first }
        set { forkParent = newValue.map { [$0] } ?? [] }
    }
    // An array gives the recursive value the indirection it needs.
    var forkParent: [Gist] = []

    /// One file in a gist.
    public struct File: Sendable, Hashable, Codable {
        public var filename: String?
        /// The media type, such as `text/markdown`.
        public var type: String?
        public var language: String?
        public var rawURL: URL?
        public var size: Int?
        /// `true` when ``content`` holds only the first megabyte. Download ``rawURL`` for the rest.
        public var isTruncated: Bool?
        public var content: String?
        /// How ``content`` is encoded: `utf-8` or `base64`.
        public var encoding: String?

        enum CodingKeys: String, CodingKey {
            case filename, type, language, size, content, encoding
            case rawURL = "raw_url"
            case isTruncated = "truncated"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, url, files, description, owner, history
        case nodeID = "node_id"
        case forksURL = "forks_url"
        case commitsURL = "commits_url"
        case commentsURL = "comments_url"
        case gitPullURL = "git_pull_url"
        case gitPushURL = "git_push_url"
        case htmlURL = "html_url"
        case isPublic = "public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case commentCount = "comments"
        case commentsEnabled = "comments_enabled"
        case isTruncated = "truncated"
        case forkOf = "fork_of"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nodeID = try c.decodeIfPresent(String.self, forKey: .nodeID)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        forksURL = try c.decodeIfPresent(URL.self, forKey: .forksURL)
        commitsURL = try c.decodeIfPresent(URL.self, forKey: .commitsURL)
        commentsURL = try c.decodeIfPresent(URL.self, forKey: .commentsURL)
        gitPullURL = try c.decodeIfPresent(URL.self, forKey: .gitPullURL)
        gitPushURL = try c.decodeIfPresent(URL.self, forKey: .gitPushURL)
        htmlURL = try c.decodeIfPresent(URL.self, forKey: .htmlURL)
        // A file is `null` when an update just deleted it.
        files = try c.decodeIfPresent([String: File?].self, forKey: .files)?.compactMapValues { $0 } ?? [:]
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        commentCount = try c.decodeIfPresent(Int.self, forKey: .commentCount)
        commentsEnabled = try c.decodeIfPresent(Bool.self, forKey: .commentsEnabled)
        owner = try c.decodeIfPresent(SimpleUser.self, forKey: .owner)
        isTruncated = try c.decodeIfPresent(Bool.self, forKey: .isTruncated)
        history = try c.decodeIfPresent([GistCommit].self, forKey: .history)
        forkOf = try c.decodeIfPresent(Gist.self, forKey: .forkOf)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(nodeID, forKey: .nodeID)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(forksURL, forKey: .forksURL)
        try c.encodeIfPresent(commitsURL, forKey: .commitsURL)
        try c.encodeIfPresent(commentsURL, forKey: .commentsURL)
        try c.encodeIfPresent(gitPullURL, forKey: .gitPullURL)
        try c.encodeIfPresent(gitPushURL, forKey: .gitPushURL)
        try c.encodeIfPresent(htmlURL, forKey: .htmlURL)
        try c.encode(files, forKey: .files)
        try c.encode(isPublic, forKey: .isPublic)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
        try c.encodeIfPresent(commentsEnabled, forKey: .commentsEnabled)
        try c.encodeIfPresent(owner, forKey: .owner)
        try c.encodeIfPresent(isTruncated, forKey: .isTruncated)
        try c.encodeIfPresent(history, forKey: .history)
        try c.encodeIfPresent(forkOf, forKey: .forkOf)
    }
}

/// One revision of a gist (`gist-commit` and `gist-history`).
public struct GistCommit: Sendable, Hashable, Codable {
    public var url: URL?
    /// The revision's commit SHA. Pass it to ``GistsAPI/gist(id:revision:)``.
    public var version: String
    public var user: SimpleUser?
    public var changeStatus: ChangeStatus?
    public var committedAt: Date?

    /// The lines a revision changed.
    public struct ChangeStatus: Sendable, Hashable, Codable {
        public var total: Int?
        public var additions: Int?
        public var deletions: Int?
    }

    enum CodingKeys: String, CodingKey {
        case url, version, user
        case changeStatus = "change_status"
        case committedAt = "committed_at"
    }
}

/// A comment on a gist (`gist-comment`).
public struct GistComment: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    public var url: URL?
    public var body: String
    public var user: SimpleUser?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var authorAssociation: AuthorAssociation?

    enum CodingKeys: String, CodingKey {
        case id, url, body, user
        case nodeID = "node_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorAssociation = "author_association"
    }
}

/// Which gists to list.
public enum GistCollection: Sendable, Hashable {
    /// The signed-in user's gists, or public gists when signed out.
    case signedInUser
    /// A user's public gists.
    case user(String)
    /// Public gists across GitHub, newest first.
    case `public`
    /// Gists the signed-in user starred.
    case starred

    var path: String {
        switch self {
        case .signedInUser: "/gists"
        case .user(let login): "/users/\(escape(login))/gists"
        case .public: "/gists/public"
        case .starred: "/gists/starred"
        }
    }
}

/// A gist to create.
public struct NewGist: Sendable, Hashable, Encodable {
    public var description: String?
    /// The files' contents by file name.
    public var files: [String: String]
    /// `true` for a public gist. Gists are secret unless you say otherwise.
    public var isPublic: Bool?

    public init(description: String? = nil, files: [String: String], isPublic: Bool? = nil) {
        self.description = description
        self.files = files
        self.isPublic = isPublic
    }

    enum CodingKeys: String, CodingKey {
        case description, files
        case isPublic = "public"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(files.mapValues { ["content": $0] }, forKey: .files)
        try c.encodeIfPresent(isPublic, forKey: .isPublic)
    }
}

/// Changes to a gist. Files you leave out stay as they are.
public struct GistUpdate: Sendable, Hashable, Encodable {
    public var description: String?
    /// The changes by current file name. Use a new name to add a file.
    public var files: [String: FileChange]

    public init(description: String? = nil, files: [String: FileChange] = [:]) {
        self.description = description
        self.files = files
    }

    /// A change to one file.
    public enum FileChange: Sendable, Hashable, Encodable {
        /// Replaces the file's content, or adds the file.
        case content(String)
        /// Renames the file, and replaces its content if you pass some.
        case rename(to: String, content: String? = nil)
        /// Deletes the file.
        case delete

        enum CodingKeys: String, CodingKey { case content, filename }

        public func encode(to encoder: any Encoder) throws {
            switch self {
            case .content(let content):
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(content, forKey: .content)
            case .rename(let filename, let content):
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(filename, forKey: .filename)
                try c.encodeIfPresent(content, forKey: .content)
            case .delete:
                var c = encoder.singleValueContainer()
                try c.encodeNil()
            }
        }
    }

    enum CodingKeys: String, CodingKey { case description, files }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(description, forKey: .description)
        if !files.isEmpty { try c.encode(files, forKey: .files) }
    }
}
