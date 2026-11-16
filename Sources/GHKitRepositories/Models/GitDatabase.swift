import Foundation
import GHKitCore

/// A file's content as Git stores it (`blob`).
public struct GitBlob: Sendable, Hashable, Codable, Identifiable {
    public var sha: String
    public var nodeID: String?
    public var url: URL?
    /// The size in bytes.
    public var size: Int?
    /// The content in ``encoding``, which is usually `base64`. Use ``data`` for the bytes.
    public var content: String
    public var encoding: String

    public var id: String { sha }

    /// The content's bytes, or `nil` for an encoding other than `base64` or `utf-8`.
    public var data: Data? {
        switch encoding {
        case "base64": Data(base64Encoded: content, options: .ignoreUnknownCharacters)
        case "utf-8": Data(content.utf8)
        default: nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case sha, url, size, content, encoding
        case nodeID = "node_id"
    }
}

/// The kind of a Git object.
public struct GitObjectType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let blob: Self = "blob"
    public static let tree: Self = "tree"
    public static let commit: Self = "commit"
    public static let tag: Self = "tag"
}

/// The object a reference or tag points to.
public struct GitObject: Sendable, Hashable, Codable {
    public var type: GitObjectType
    public var sha: String
    public var url: URL?
}

/// A branch or tag name and the object it points to (`git-ref`).
public struct GitReference: Sendable, Hashable, Codable, Identifiable {
    /// The full name, such as `refs/heads/main`.
    public var ref: String
    public var nodeID: String?
    public var url: URL?
    public var object: GitObject

    public var id: String { ref }

    enum CodingKeys: String, CodingKey {
        case ref, url, object
        case nodeID = "node_id"
    }
}

/// An annotated tag object (`git-tag`).
public struct GitTag: Sendable, Hashable, Codable, Identifiable {
    public var sha: String
    public var nodeID: String?
    public var url: URL?
    /// The tag's name, such as `v1.0`.
    public var tag: String
    public var message: String
    public var tagger: GitActor
    public var object: GitObject
    public var verification: GitCommit.Verification?

    public var id: String { sha }

    enum CodingKeys: String, CodingKey {
        case sha, url, tag, message, tagger, object, verification
        case nodeID = "node_id"
    }
}

/// The file mode of a tree entry.
public struct GitFileMode: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let file: Self = "100644"
    public static let executable: Self = "100755"
    public static let directory: Self = "040000"
    public static let submodule: Self = "160000"
    public static let symlink: Self = "120000"
}

/// The files and folders at one level of a repository, or every level of it (`git-tree`).
public struct GitTree: Sendable, Hashable, Codable, Identifiable {
    public var sha: String
    public var url: URL?
    public var entries: [Entry]
    /// Whether GitHub stopped listing a recursive tree early. Fetch subtrees one at a time to see the rest.
    public var truncated: Bool

    public var id: String { sha }

    /// A file, folder, or submodule in a tree.
    public struct Entry: Sendable, Hashable, Codable {
        /// The path, relative to the tree.
        public var path: String
        public var mode: GitFileMode
        public var type: GitObjectType
        public var sha: String
        /// The size in bytes, for blobs.
        public var size: Int?
        public var url: URL?
    }

    enum CodingKeys: String, CodingKey {
        case sha, url, truncated
        case entries = "tree"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sha = try c.decode(String.self, forKey: .sha)
        url = try c.decodeIfPresent(URL.self, forKey: .url)
        entries = try c.decode([Entry].self, forKey: .entries)
        truncated = try c.decodeIfPresent(Bool.self, forKey: .truncated) ?? false
    }
}

// MARK: - Inputs

/// One change in ``GitDatabaseAPI/createTree(_:base:)``: a file to add or replace, or a path to delete.
public struct NewGitTreeEntry: Sendable, Hashable, Encodable {
    public var path: String
    public var mode: GitFileMode
    public var type: GitObjectType
    public var source: Source

    /// Where the entry's content comes from.
    public enum Source: Sendable, Hashable {
        /// An object that already exists, by SHA.
        case sha(String)
        /// Text that GitHub stores as a new blob.
        case content(String)
        /// Nothing: the path is removed from the base tree.
        case delete
    }

    public init(path: String, mode: GitFileMode, type: GitObjectType, source: Source) {
        self.path = path
        self.mode = mode
        self.type = type
        self.source = source
    }

    /// A file with this text.
    public static func file(_ path: String, content: String, mode: GitFileMode = .file) -> Self {
        Self(path: path, mode: mode, type: .blob, source: .content(content))
    }

    /// A file with an existing blob's content, such as one from ``GitDatabaseAPI/createBlob(_:)``.
    public static func blob(_ path: String, sha: String, mode: GitFileMode = .file) -> Self {
        Self(path: path, mode: mode, type: .blob, source: .sha(sha))
    }

    /// A folder with an existing tree's content.
    public static func tree(_ path: String, sha: String) -> Self {
        Self(path: path, mode: .directory, type: .tree, source: .sha(sha))
    }

    /// Removes a file from the base tree.
    public static func delete(_ path: String) -> Self {
        Self(path: path, mode: .file, type: .blob, source: .delete)
    }

    enum CodingKeys: String, CodingKey { case path, mode, type, sha, content }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(path, forKey: .path)
        try c.encode(mode, forKey: .mode)
        try c.encode(type, forKey: .type)
        switch source {
        case .sha(let sha): try c.encode(sha, forKey: .sha)
        case .content(let content): try c.encode(content, forKey: .content)
        // GitHub deletes the path only when `sha` is an explicit null.
        case .delete: try c.encodeNil(forKey: .sha)
        }
    }
}

/// A commit for ``GitDatabaseAPI/createCommit(_:)``.
public struct NewGitCommit: Sendable, Hashable, Encodable {
    public var message: String
    /// The SHA of the commit's tree.
    public var tree: String
    /// The SHAs of the parent commits: one for a normal commit, two or more for a merge, none for a root commit.
    public var parents: [String]
    /// Defaults to the signed-in user, now.
    public var author: GitActor?
    /// Defaults to the author.
    public var committer: GitActor?
    /// An ASCII-armored PGP or SSH signature of the commit, which GitHub stores in its `gpgsig` header.
    public var signature: String?

    public init(
        message: String, tree: String, parents: [String], author: GitActor? = nil, committer: GitActor? = nil, signature: String? = nil
    ) {
        self.message = message
        self.tree = tree
        self.parents = parents
        self.author = author
        self.committer = committer
        self.signature = signature
    }
}

/// An annotated tag for ``GitDatabaseAPI/createTag(_:)``.
public struct NewGitTag: Sendable, Hashable, Encodable {
    /// The tag's name, such as `v1.0`.
    public var tag: String
    public var message: String
    /// The SHA of the object to tag.
    public var object: String
    public var type: GitObjectType
    /// Defaults to the signed-in user, now.
    public var tagger: GitActor?

    public init(_ tag: String, message: String, object: String, type: GitObjectType = .commit, tagger: GitActor? = nil) {
        self.tag = tag
        self.message = message
        self.object = object
        self.type = type
        self.tagger = tagger
    }
}
