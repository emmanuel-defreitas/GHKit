import Foundation

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
