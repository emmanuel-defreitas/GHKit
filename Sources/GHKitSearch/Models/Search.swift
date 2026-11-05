import Foundation
import GHKitCore

/// One search hit: the matched item plus how well it matched.
///
/// Read the item's properties straight off the result, such as `result.fullName` for a repository.
@dynamicMemberLookup
public struct SearchResult<Item: Sendable & Hashable & Codable>: Sendable, Hashable, Codable {
    public var item: Item
    /// How well the item matched. Higher is better.
    public var score: Double?
    /// The matched text, when you ask for it with `textMatches: true`.
    public var textMatches: [TextMatch]?
    /// The repository a commit or code match is in.
    public var repository: Repository?

    public subscript<Value>(dynamicMember keyPath: KeyPath<Item, Value>) -> Value {
        item[keyPath: keyPath]
    }

    enum CodingKeys: String, CodingKey {
        case score, repository
        case textMatches = "text_matches"
    }

    public init(from decoder: any Decoder) throws {
        item = try Item(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try c.decodeIfPresent(Double.self, forKey: .score)
        textMatches = try c.decodeIfPresent([TextMatch].self, forKey: .textMatches)
        repository = try c.decodeIfPresent(Repository.self, forKey: .repository)
    }

    public func encode(to encoder: any Encoder) throws {
        try item.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(score, forKey: .score)
        try c.encodeIfPresent(textMatches, forKey: .textMatches)
        try c.encodeIfPresent(repository, forKey: .repository)
    }
}

/// A snippet of matched text in a search hit (`search-result-text-matches`).
public struct TextMatch: Sendable, Hashable, Codable {
    public var objectURL: String?
    public var objectType: String?
    /// The property that matched, such as `body` or `content`.
    public var property: String?
    /// The text around the matches.
    public var fragment: String?
    public var matches: [Match]?

    /// One matched term and where it is in ``fragment``.
    public struct Match: Sendable, Hashable, Codable {
        public var text: String?
        /// The start and end offsets of the match in the fragment.
        public var indices: [Int]?
    }

    enum CodingKeys: String, CodingKey {
        case property, fragment, matches
        case objectURL = "object_url"
        case objectType = "object_type"
    }
}

/// The size of a search's results.
public struct SearchSummary: Sendable, Hashable, Codable {
    /// How many items match. You can page through the first 1,000.
    public var totalCount: Int
    /// `true` when the search timed out and the results may be missing items.
    public var isIncomplete: Bool
    /// For issue searches, how GitHub ran the search: `lexical`, `semantic`, or `hybrid`.
    public var searchType: String?
    /// For issue searches that asked for semantic search but got lexical results, the reasons why.
    public var lexicalFallbackReasons: [String]?

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case isIncomplete = "incomplete_results"
        case searchType = "search_type"
        case lexicalFallbackReasons = "lexical_fallback_reason"
    }
}

/// A file that matched a code search (`code-search-result-item`). Its repository is on the ``SearchResult``.
public struct CodeFile: Sendable, Hashable, Codable {
    public var name: String
    public var path: String
    public var sha: String
    public var url: URL?
    public var gitURL: URL?
    public var htmlURL: URL?
    public var fileSize: Int?
    public var language: String?
    public var lastModifiedAt: Date?
    public var lineNumbers: [String]?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, url, language
        case gitURL = "git_url"
        case htmlURL = "html_url"
        case fileSize = "file_size"
        case lastModifiedAt = "last_modified_at"
        case lineNumbers = "line_numbers"
    }
}

/// A GitHub topic (`topic-search-result-item`).
public struct Topic: Sendable, Hashable, Codable {
    public var name: String
    public var displayName: String?
    public var shortDescription: String?
    public var description: String?
    public var createdBy: String?
    public var released: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var isFeatured: Bool
    public var isCurated: Bool
    public var repositoryCount: Int?
    public var logoURL: URL?
    public var related: [Relation]?
    public var aliases: [Relation]?

    /// A topic that's related to, or another name for, this one.
    public struct Relation: Sendable, Hashable, Codable {
        public var id: Int?
        public var name: String?
        public var topicID: Int?
        public var relationType: String?

        enum Wrapper: String, CodingKey { case topicRelation = "topic_relation" }

        enum CodingKeys: String, CodingKey {
            case id, name
            case topicID = "topic_id"
            case relationType = "relation_type"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Wrapper.self).nestedContainer(keyedBy: CodingKeys.self, forKey: .topicRelation)
            id = try c.decodeIfPresent(Int.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            topicID = try c.decodeIfPresent(Int.self, forKey: .topicID)
            relationType = try c.decodeIfPresent(String.self, forKey: .relationType)
        }

        public func encode(to encoder: any Encoder) throws {
            var wrapper = encoder.container(keyedBy: Wrapper.self)
            var c = wrapper.nestedContainer(keyedBy: CodingKeys.self, forKey: .topicRelation)
            try c.encodeIfPresent(id, forKey: .id)
            try c.encodeIfPresent(name, forKey: .name)
            try c.encodeIfPresent(topicID, forKey: .topicID)
            try c.encodeIfPresent(relationType, forKey: .relationType)
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, description, released, related, aliases
        case displayName = "display_name"
        case shortDescription = "short_description"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isFeatured = "featured"
        case isCurated = "curated"
        case repositoryCount = "repository_count"
        case logoURL = "logo_url"
    }
}

/// How to sort commit search results.
public enum CommitSearchSort: String, Sendable, Hashable, CustomStringConvertible {
    case authorDate = "author-date"
    case committerDate = "committer-date"
    public var description: String { rawValue }
}

/// How to sort issue and pull request search results.
public enum IssueSearchSort: String, Sendable, Hashable, CustomStringConvertible {
    case comments, reactions, interactions, created, updated
    case thumbsUpReactions = "reactions-+1"
    case thumbsDownReactions = "reactions--1"
    case laughReactions = "reactions-smile"
    case confusedReactions = "reactions-thinking_face"
    case heartReactions = "reactions-heart"
    case hoorayReactions = "reactions-tada"
    public var description: String { rawValue }
}

/// How GitHub matches an issue search's text.
public enum IssueSearchMode: String, Sendable, Hashable, CustomStringConvertible {
    /// By meaning rather than exact words.
    case semantic
    /// By meaning and by exact words.
    case hybrid
    public var description: String { rawValue }
}

/// How to sort label search results.
public enum LabelSearchSort: String, Sendable, Hashable, CustomStringConvertible {
    case created, updated
    public var description: String { rawValue }
}

/// How to sort repository search results.
public enum RepositorySearchSort: String, Sendable, Hashable, CustomStringConvertible {
    case stars, forks, updated
    case helpWantedIssues = "help-wanted-issues"
    public var description: String { rawValue }
}

/// How to sort user search results.
public enum UserSearchSort: String, Sendable, Hashable, CustomStringConvertible {
    case followers, repositories, joined
    public var description: String { rawValue }
}
