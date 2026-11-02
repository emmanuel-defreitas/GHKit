import Foundation

/// A file, directory, symlink, or submodule in a repository (`content-file`, `content-symlink`, `content-submodule`).
///
/// Directory listings leave out `content`. Files over 1 MB also have no `content`; use
/// `RepositoriesAPI.rawContents(_:_:at:ref:)` for those.
public struct RepositoryContent: Sendable, Hashable, Codable, Identifiable {
    public var type: ContentType
    public var name: String
    public var path: String
    /// The blob SHA. Pass it back when updating or deleting the file.
    public var sha: String
    /// Bytes.
    public var size: Int
    /// Base64, wrapped at 60 characters. Prefer `data` or `text`.
    public var content: String?
    /// `base64`, or `none` for files too large to inline.
    public var encoding: String?
    /// For symlinks, the path the link points to.
    public var target: String?
    /// For submodules, the submodule's Git URL.
    public var submoduleGitURL: URL?
    public var url: URL?
    public var htmlURL: URL?
    public var gitURL: URL?
    public var downloadURL: URL?

    public var id: String { path }

    /// The decoded file bytes, when `content` is base64.
    public var data: Data? {
        guard encoding == "base64", let content else { return nil }
        return Data(base64Encoded: content.filter { !$0.isWhitespace })
    }

    /// The file as UTF-8 text.
    public var text: String? { data.flatMap { String(data: $0, encoding: .utf8) } }

    enum CodingKeys: String, CodingKey {
        case type, name, path, sha, size, content, encoding, target, url
        case submoduleGitURL = "submodule_git_url"
        case htmlURL = "html_url"
        case gitURL = "git_url"
        case downloadURL = "download_url"
    }
}

/// What a repository path holds.
public struct ContentType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let file: Self = "file"
    public static let directory: Self = "dir"
    public static let symlink: Self = "symlink"
    public static let submodule: Self = "submodule"
}

/// The result of reading a path: one item, or a directory's entries.
public enum Contents: Sendable, Hashable, Decodable {
    /// A file, symlink, or submodule.
    case item(RepositoryContent)
    case directory([RepositoryContent])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let entries = try? container.decode([RepositoryContent].self) {
            self = .directory(entries)
        } else {
            self = .item(try container.decode(RepositoryContent.self))
        }
    }

    /// The item, or `nil` for a directory.
    public var item: RepositoryContent? {
        if case .item(let item) = self { item } else { nil }
    }

    /// The directory's entries, or `nil` for a single item.
    public var entries: [RepositoryContent]? {
        if case .directory(let entries) = self { entries } else { nil }
    }
}

/// A name, email, and optional date for a commit's author or committer.
public struct GitActor: Sendable, Hashable, Codable {
    public var name: String
    public var email: String
    public var date: Date?

    public init(name: String, email: String, date: Date? = nil) {
        self.name = name
        self.email = email
        self.date = date
    }
}

/// A Git commit object (`git-commit`).
public struct GitCommit: Sendable, Hashable, Codable, Identifiable {
    public var sha: String
    public var nodeID: String?
    public var url: URL?
    public var htmlURL: URL?
    public var author: GitActor
    public var committer: GitActor
    public var message: String
    public var tree: Pointer
    public var parents: [Pointer]
    public var verification: Verification?

    public var id: String { sha }

    /// A SHA with its URLs, for trees and parent commits.
    public struct Pointer: Sendable, Hashable, Codable {
        public var sha: String
        public var url: URL?
        public var htmlURL: URL?

        enum CodingKeys: String, CodingKey {
            case sha, url
            case htmlURL = "html_url"
        }
    }

    /// Whether GitHub could verify the commit's signature.
    public struct Verification: Sendable, Hashable, Codable {
        public var verified: Bool
        /// Such as `valid`, `unsigned`, or `unknown_key`.
        public var reason: String
        public var signature: String?
        public var payload: String?
        public var verifiedAt: Date?

        enum CodingKeys: String, CodingKey {
            case verified, reason, signature, payload
            case verifiedAt = "verified_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case sha, url, author, committer, message, tree, parents, verification
        case nodeID = "node_id"
        case htmlURL = "html_url"
    }
}

/// A file written to a repository.
public struct FileChange: Sendable, Hashable, Encodable {
    public var message: String
    public var content: Data
    /// The current blob SHA. Required when replacing a file.
    public var sha: String?
    /// Defaults to the repository's default branch.
    public var branch: String?
    /// Defaults to the signed-in user.
    public var committer: GitActor?
    /// Defaults to the committer.
    public var author: GitActor?

    public init(
        message: String, content: Data, replacing sha: String? = nil, branch: String? = nil, committer: GitActor? = nil,
        author: GitActor? = nil
    ) {
        self.message = message
        self.content = content
        self.sha = sha
        self.branch = branch
        self.committer = committer
        self.author = author
    }

    /// A text file, stored as UTF-8.
    public init(
        message: String, text: String, replacing sha: String? = nil, branch: String? = nil, committer: GitActor? = nil,
        author: GitActor? = nil
    ) {
        self.init(message: message, content: Data(text.utf8), replacing: sha, branch: branch, committer: committer, author: author)
    }

    enum CodingKeys: String, CodingKey { case message, content, sha, branch, committer, author }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(message, forKey: .message)
        try c.encode(content.base64EncodedString(), forKey: .content)
        try c.encodeIfPresent(sha, forKey: .sha)
        try c.encodeIfPresent(branch, forKey: .branch)
        try c.encodeIfPresent(committer, forKey: .committer)
        try c.encodeIfPresent(author, forKey: .author)
    }
}

/// The commit a file change made, and the file as it now is (`file-commit`).
public struct FileCommit: Sendable, Hashable, Codable {
    /// `nil` after a delete.
    public var content: RepositoryContent?
    public var commit: GitCommit
}

/// A repository's license file and the license GitHub detected (`license-content`).
public struct RepositoryLicense: Sendable, Hashable, Codable {
    public var file: RepositoryContent
    public var license: LicenseSummary?

    enum CodingKeys: String, CodingKey { case license }

    public init(from decoder: any Decoder) throws {
        file = try RepositoryContent(from: decoder)
        license = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(LicenseSummary.self, forKey: .license)
    }

    public func encode(to encoder: any Encoder) throws {
        try file.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(license, forKey: .license)
    }
}

/// A problem in a CODEOWNERS file.
public struct CodeownersError: Sendable, Hashable, Codable {
    public var line: Int
    public var column: Int
    /// Such as `Invalid pattern` or `Invalid owner`.
    public var kind: String
    public var source: String?
    public var suggestion: String?
    /// A ready-to-show explanation, with the offending line.
    public var message: String
    public var path: String
}

/// What syncing a fork with its upstream did (`merged-upstream`).
public struct MergeUpstreamResult: Sendable, Hashable, Codable {
    public var message: String?
    /// `merge`, `fast-forward`, or `none` when already up to date.
    public var mergeType: String?
    public var baseBranch: String?

    enum CodingKeys: String, CodingKey {
        case message
        case mergeType = "merge_type"
        case baseBranch = "base_branch"
    }
}

/// A repository to create from a template.
public struct NewRepositoryFromTemplate: Sendable, Hashable, Encodable {
    public var name: String
    /// A user or organization login. Defaults to the signed-in user.
    public var owner: String?
    public var description: String?
    public var isPrivate: Bool?
    /// Copies every branch, not just the default one.
    public var includeAllBranches: Bool?

    public init(
        name: String, owner: String? = nil, description: String? = nil, isPrivate: Bool? = nil,
        includeAllBranches: Bool? = nil
    ) {
        self.name = name
        self.owner = owner
        self.description = description
        self.isPrivate = isPrivate
        self.includeAllBranches = includeAllBranches
    }

    enum CodingKeys: String, CodingKey {
        case name, owner, description
        case isPrivate = "private"
        case includeAllBranches = "include_all_branches"
    }
}

/// A source archive format.
public enum ArchiveFormat: String, Sendable, Hashable {
    case tarball, zipball
}

/// How to sort forks.
public enum ForkSort: String, Sendable, Hashable, CustomStringConvertible {
    case newest, oldest, stargazers, watchers
    public var description: String { rawValue }
}
