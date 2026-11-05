import Foundation

/// Reaction counts on a release, issue, or comment (`reaction-rollup`).
public struct ReactionSummary: Sendable, Hashable, Codable {
    public var url: URL?
    public var totalCount: Int
    public var thumbsUp: Int
    public var thumbsDown: Int
    public var laugh: Int
    public var confused: Int
    public var heart: Int
    public var hooray: Int
    public var eyes: Int
    public var rocket: Int

    enum CodingKeys: String, CodingKey {
        case url, laugh, confused, heart, hooray, eyes, rocket
        case totalCount = "total_count"
        case thumbsUp = "+1"
        case thumbsDown = "-1"
    }
}
