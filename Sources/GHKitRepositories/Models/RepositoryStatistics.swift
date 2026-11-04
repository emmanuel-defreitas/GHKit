import Foundation
import GHKitCore

// MARK: Traffic

/// Views or clones over the last 14 days (`view-traffic`, `clone-traffic`).
public struct RepositoryTraffic: Sendable, Hashable, Codable {
    public var count: Int
    /// Unique visitors or cloners.
    public var uniques: Int
    /// Counts per day or per week, oldest first.
    public var breakdown: [TrafficCount]

    enum CodingKeys: String, CodingKey { case count, uniques, views, clones }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = try c.decode(Int.self, forKey: .count)
        uniques = try c.decode(Int.self, forKey: .uniques)
        breakdown = try c.decodeIfPresent([TrafficCount].self, forKey: .views) ?? c.decodeIfPresent([TrafficCount].self, forKey: .clones) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(count, forKey: .count)
        try c.encode(uniques, forKey: .uniques)
        try c.encode(breakdown, forKey: .views)
    }
}

/// Views or clones in one day or week (`traffic`).
public struct TrafficCount: Sendable, Hashable, Codable {
    /// The start of the day or week.
    public var timestamp: Date
    public var count: Int
    public var uniques: Int
}

/// Groups traffic by day or by week.
public enum TrafficPeriod: String, Sendable, Hashable, CustomStringConvertible {
    case day, week
    public var description: String { rawValue }
}

/// One of a repository's most viewed pages (`content-traffic`).
public struct PopularContent: Sendable, Hashable, Codable {
    /// The path on GitHub, such as `/octocat/Hello-World/blob/main/README.md`.
    public var path: String
    public var title: String
    public var count: Int
    public var uniques: Int
}

/// A site that sends visitors to a repository (`referrer-traffic`).
public struct TrafficReferrer: Sendable, Hashable, Codable {
    /// Such as `google.com`.
    public var referrer: String
    public var count: Int
    public var uniques: Int
}

// MARK: Statistics

/// Lines added and deleted in one week (`code-frequency-stat`).
public struct WeeklyCodeFrequency: Sendable, Hashable, Codable {
    public var week: Date
    public var additions: Int
    /// A positive count of lines deleted.
    public var deletions: Int

    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        week = Date(timeIntervalSince1970: TimeInterval(try c.decode(Int.self)))
        additions = try c.decode(Int.self)
        // GitHub sends deletions as a negative number.
        deletions = abs(try c.decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(Int(week.timeIntervalSince1970))
        try c.encode(additions)
        try c.encode(-deletions)
    }
}

/// Commits per day in one week (`commit-activity`).
public struct WeeklyCommitActivity: Sendable, Hashable, Codable {
    /// The start of the week, a Sunday.
    public var week: Date
    public var total: Int
    /// Commits on each day, Sunday first.
    public var days: [Int]

    enum CodingKeys: String, CodingKey { case week, total, days }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        week = Date(timeIntervalSince1970: TimeInterval(try c.decode(Int.self, forKey: .week)))
        total = try c.decode(Int.self, forKey: .total)
        days = try c.decode([Int].self, forKey: .days)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Int(week.timeIntervalSince1970), forKey: .week)
        try c.encode(total, forKey: .total)
        try c.encode(days, forKey: .days)
    }
}

/// A contributor's commits, additions, and deletions per week (`contributor-activity`).
public struct ContributorStatistics: Sendable, Hashable, Codable {
    public var author: SimpleUser?
    /// Commits over the repository's history.
    public var total: Int
    public var weeks: [Week]

    /// One week of a contributor's activity.
    public struct Week: Sendable, Hashable, Codable {
        public var start: Date
        public var additions: Int
        public var deletions: Int
        public var commits: Int

        enum CodingKeys: String, CodingKey {
            case start = "w"
            case additions = "a"
            case deletions = "d"
            case commits = "c"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            start = Date(timeIntervalSince1970: TimeInterval(try c.decode(Int.self, forKey: .start)))
            additions = try c.decodeIfPresent(Int.self, forKey: .additions) ?? 0
            deletions = try c.decodeIfPresent(Int.self, forKey: .deletions) ?? 0
            commits = try c.decodeIfPresent(Int.self, forKey: .commits) ?? 0
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(Int(start.timeIntervalSince1970), forKey: .start)
            try c.encode(additions, forKey: .additions)
            try c.encode(deletions, forKey: .deletions)
            try c.encode(commits, forKey: .commits)
        }
    }

    enum CodingKeys: String, CodingKey { case author, total, weeks }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        author = try? c.decodeIfPresent(SimpleUser.self, forKey: .author)
        total = try c.decode(Int.self, forKey: .total)
        weeks = try c.decode([Week].self, forKey: .weeks)
    }
}

/// Weekly commit counts for the last 52 weeks, oldest first (`participation-stats`).
public struct ParticipationStatistics: Sendable, Hashable, Codable {
    /// Commits by everyone.
    public var all: [Int]
    /// Commits by the repository owner.
    public var owner: [Int]
}

/// Commits in one hour of the week, across the repository's history (`code-frequency-stat`).
public struct PunchCardHour: Sendable, Hashable, Codable {
    /// 0 is Sunday.
    public var weekday: Int
    /// 0 to 23, in UTC.
    public var hour: Int
    public var commits: Int

    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        weekday = try c.decode(Int.self)
        hour = try c.decode(Int.self)
        commits = try c.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(weekday)
        try c.encode(hour)
        try c.encode(commits)
    }
}
