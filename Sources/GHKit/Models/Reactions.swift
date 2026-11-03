import Foundation

/// An emoji reaction.
public struct ReactionContent: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    /// 👍
    public static let thumbsUp: Self = "+1"
    /// 👎. Not allowed on releases.
    public static let thumbsDown: Self = "-1"
    /// 😄
    public static let laugh: Self = "laugh"
    /// 😕. Not allowed on releases.
    public static let confused: Self = "confused"
    /// ❤️
    public static let heart: Self = "heart"
    /// 🎉
    public static let hooray: Self = "hooray"
    /// 🚀
    public static let rocket: Self = "rocket"
    /// 👀
    public static let eyes: Self = "eyes"
}

/// Someone's emoji reaction (`reaction`).
public struct Reaction: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String
    public var user: SimpleUser?
    public var content: ReactionContent
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, user, content
        case nodeID = "node_id"
        case createdAt = "created_at"
    }
}

/// Something in a repository that takes reactions.
public enum ReactionSubject: Sendable, Hashable {
    /// An issue or pull request, by number.
    case issue(Int)
    /// A comment on an issue or pull request conversation.
    case issueComment(id: Int)
    /// A comment on a commit.
    case commitComment(id: Int)
    /// A comment on a pull request's diff.
    case reviewComment(id: Int)
    case release(id: Int)

    var path: String {
        switch self {
        case .issue(let number): "/issues/\(number)/reactions"
        case .issueComment(let id): "/issues/comments/\(id)/reactions"
        case .commitComment(let id): "/comments/\(id)/reactions"
        case .reviewComment(let id): "/pulls/comments/\(id)/reactions"
        case .release(let id): "/releases/\(id)/reactions"
        }
    }
}
