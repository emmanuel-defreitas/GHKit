import Foundation
import GHKitCore

// MARK: Events

/// Something that happened on GitHub, such as a push or a new issue (`event`).
///
/// The payload depends on ``type``. Decode it with `payload.decode(as:)` or read it with subscripts.
public struct GitHubEvent: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var type: GitHubEventType?
    public var actor: Actor
    public var repository: RepositoryReference
    public var organization: Actor?
    public var payload: JSONValue
    public var isPublic: Bool
    public var createdAt: Date?

    /// The account behind an event, or the organization it happened in.
    public struct Actor: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var login: String
        public var displayLogin: String?
        public var gravatarID: String?
        public var url: URL?
        public var avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case id, login, url
            case displayLogin = "display_login"
            case gravatarID = "gravatar_id"
            case avatarURL = "avatar_url"
        }
    }

    /// The repository an event happened in.
    public struct RepositoryReference: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        /// The full name, such as `octocat/Hello-World`.
        public var name: String
        public var url: URL?
    }

    enum CodingKeys: String, CodingKey {
        case id, type, actor, payload
        case repository = "repo"
        case organization = "org"
        case isPublic = "public"
        case createdAt = "created_at"
    }
}

/// The kind of a ``GitHubEvent``.
public struct GitHubEventType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let commitComment: Self = "CommitCommentEvent"
    public static let create: Self = "CreateEvent"
    public static let delete: Self = "DeleteEvent"
    public static let discussion: Self = "DiscussionEvent"
    public static let fork: Self = "ForkEvent"
    public static let gollum: Self = "GollumEvent"
    public static let issueComment: Self = "IssueCommentEvent"
    public static let issues: Self = "IssuesEvent"
    public static let member: Self = "MemberEvent"
    public static let `public`: Self = "PublicEvent"
    public static let pullRequest: Self = "PullRequestEvent"
    public static let pullRequestReview: Self = "PullRequestReviewEvent"
    public static let pullRequestReviewComment: Self = "PullRequestReviewCommentEvent"
    public static let pullRequestReviewThread: Self = "PullRequestReviewThreadEvent"
    public static let push: Self = "PushEvent"
    public static let release: Self = "ReleaseEvent"
    public static let sponsorship: Self = "SponsorshipEvent"
    /// Someone starred a repository.
    public static let watch: Self = "WatchEvent"
}

/// Where to read events from.
public enum EventSource: Sendable, Hashable {
    /// Public events across GitHub.
    case everyone
    /// Events in a repository.
    case repository(owner: String, name: String)
    /// Public events in a repository and its forks.
    case network(owner: String, name: String)
    /// Public events in an organization.
    case organization(String)
    /// Events a user performed. Includes private events when you're signed in as that user.
    case user(String)
    /// Public events a user performed.
    case userPublic(String)
    /// Events a user receives from the accounts and repositories they watch.
    /// Includes private events when you're signed in as that user.
    case received(String)
    /// Public events a user receives.
    case receivedPublic(String)
    /// The signed-in user's organization dashboard. `login` must be the signed-in user.
    case dashboard(login: String, organization: String)

    var path: String {
        switch self {
        case .everyone: "/events"
        case .repository(let owner, let name): "/repos/\(escape(owner))/\(escape(name))/events"
        case .network(let owner, let name): "/networks/\(escape(owner))/\(escape(name))/events"
        case .organization(let org): "/orgs/\(escape(org))/events"
        case .user(let login): "/users/\(escape(login))/events"
        case .userPublic(let login): "/users/\(escape(login))/events/public"
        case .received(let login): "/users/\(escape(login))/received_events"
        case .receivedPublic(let login): "/users/\(escape(login))/received_events/public"
        case .dashboard(let login, let org): "/users/\(escape(login))/events/orgs/\(escape(org))"
        }
    }
}

/// The signed-in user's Atom feeds (`feed`). Some URLs are templates, such as `https://github.com/{user}`.
public struct Feeds: Sendable, Hashable, Codable {
    public var timelineURL: String
    public var userURL: String
    public var currentUserPublicURL: String?
    public var currentUserURL: String?
    public var currentUserActorURL: String?
    public var currentUserOrganizationURL: String?
    public var currentUserOrganizationURLs: [URL]?
    public var securityAdvisoriesURL: String?
    public var repositoryDiscussionsURL: String?
    public var repositoryDiscussionsCategoryURL: String?
    public var links: Links

    /// Each feed's URL and media type.
    public struct Links: Sendable, Hashable, Codable {
        public var timeline: Link?
        public var user: Link?
        public var securityAdvisories: Link?
        public var currentUser: Link?
        public var currentUserPublic: Link?
        public var currentUserActor: Link?
        public var currentUserOrganization: Link?
        public var currentUserOrganizations: [Link]?
        public var repositoryDiscussions: Link?
        public var repositoryDiscussionsCategory: Link?

        enum CodingKeys: String, CodingKey {
            case timeline, user
            case securityAdvisories = "security_advisories"
            case currentUser = "current_user"
            case currentUserPublic = "current_user_public"
            case currentUserActor = "current_user_actor"
            case currentUserOrganization = "current_user_organization"
            case currentUserOrganizations = "current_user_organizations"
            case repositoryDiscussions = "repository_discussions"
            case repositoryDiscussionsCategory = "repository_discussions_category"
        }
    }

    /// A feed's URL and media type.
    public struct Link: Sendable, Hashable, Codable {
        public var href: String
        public var type: String
    }

    enum CodingKeys: String, CodingKey {
        case timelineURL = "timeline_url"
        case userURL = "user_url"
        case currentUserPublicURL = "current_user_public_url"
        case currentUserURL = "current_user_url"
        case currentUserActorURL = "current_user_actor_url"
        case currentUserOrganizationURL = "current_user_organization_url"
        case currentUserOrganizationURLs = "current_user_organization_urls"
        case securityAdvisoriesURL = "security_advisories_url"
        case repositoryDiscussionsURL = "repository_discussions_url"
        case repositoryDiscussionsCategoryURL = "repository_discussions_category_url"
        case links = "_links"
    }
}

// MARK: Notifications

/// A notification: a conversation the signed-in user follows that has news (`thread`).
///
/// Named `NotificationThread` so it doesn't clash with Foundation's `Notification`.
public struct NotificationThread: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var repository: Repository
    public var subject: Subject
    public var reason: NotificationReason
    public var isUnread: Bool
    public var updatedAt: Date?
    public var lastReadAt: Date?
    public var url: URL?
    public var subscriptionURL: URL?

    /// The issue, pull request, commit, or other item a notification is about.
    public struct Subject: Sendable, Hashable, Codable {
        public var title: String
        /// The API URL of the item, or `nil` for items without one, such as some discussions.
        public var url: URL?
        public var latestCommentURL: URL?
        public var type: NotificationSubjectType

        enum CodingKeys: String, CodingKey {
            case title, url, type
            case latestCommentURL = "latest_comment_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, repository, subject, reason, url
        case isUnread = "unread"
        case updatedAt = "updated_at"
        case lastReadAt = "last_read_at"
        case subscriptionURL = "subscription_url"
    }
}

/// Why the signed-in user got a notification.
public struct NotificationReason: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let approvalRequested: Self = "approval_requested"
    public static let assign: Self = "assign"
    public static let author: Self = "author"
    public static let ciActivity: Self = "ci_activity"
    public static let comment: Self = "comment"
    public static let invitation: Self = "invitation"
    public static let manual: Self = "manual"
    public static let memberFeatureRequested: Self = "member_feature_requested"
    public static let mention: Self = "mention"
    public static let reviewRequested: Self = "review_requested"
    public static let securityAdvisoryCredit: Self = "security_advisory_credit"
    public static let securityAlert: Self = "security_alert"
    public static let stateChange: Self = "state_change"
    public static let subscribed: Self = "subscribed"
    public static let teamMention: Self = "team_mention"
}

/// The kind of item a notification is about.
public struct NotificationSubjectType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let checkSuite: Self = "CheckSuite"
    public static let commit: Self = "Commit"
    public static let discussion: Self = "Discussion"
    public static let issue: Self = "Issue"
    public static let pullRequest: Self = "PullRequest"
    public static let release: Self = "Release"
    public static let repositoryVulnerabilityAlert: Self = "RepositoryVulnerabilityAlert"
}

/// Narrows a list of notifications.
public struct NotificationFilter: Sendable, Hashable {
    /// Include notifications already marked as read.
    public var includeRead: Bool
    /// Only notifications where the user is directly involved, such as mentions and review requests.
    public var participatingOnly: Bool
    /// Only notifications updated at or after this time.
    public var since: Date?
    /// Only notifications updated before this time.
    public var before: Date?

    public init(includeRead: Bool = false, participatingOnly: Bool = false, since: Date? = nil, before: Date? = nil) {
        self.includeRead = includeRead
        self.participatingOnly = participatingOnly
        self.since = since
        self.before = before
    }

    var query: [URLQueryItem] {
        .query(
            ("all", includeRead ? true : nil), ("participating", participatingOnly ? true : nil),
            ("since", since?.ISO8601Format()), ("before", before?.ISO8601Format()))
    }
}

/// Whether the signed-in user follows a notification thread (`thread-subscription`).
public struct ThreadSubscription: Sendable, Hashable, Codable {
    public var isSubscribed: Bool
    /// `true` when notifications for the thread are muted.
    public var isIgnored: Bool
    public var reason: String?
    public var createdAt: Date?
    public var url: URL?
    public var threadURL: URL?
    public var repositoryURL: URL?

    enum CodingKeys: String, CodingKey {
        case reason, url
        case isSubscribed = "subscribed"
        case isIgnored = "ignored"
        case createdAt = "created_at"
        case threadURL = "thread_url"
        case repositoryURL = "repository_url"
    }
}

// MARK: Stars and watching

/// Someone who starred a repository, and when (`stargazer`).
public struct Stargazer: Sendable, Hashable, Codable {
    public var starredAt: Date
    public var user: SimpleUser?

    enum CodingKeys: String, CodingKey {
        case user
        case starredAt = "starred_at"
    }
}

/// A repository someone starred, and when (`starred-repository`).
public struct StarredRepository: Sendable, Hashable, Codable {
    public var starredAt: Date
    public var repository: Repository

    enum CodingKeys: String, CodingKey {
        case starredAt = "starred_at"
        case repository = "repo"
    }
}

/// A week of a repository's new stars (`stargazer-history`).
public struct StarHistoryWeek: Sendable, Hashable, Codable {
    /// The start of the week, a Sunday at midnight UTC.
    public var week: Date
    /// The stars added that week.
    public var total: Int
    /// The stars added each day, from Sunday to Saturday.
    public var days: [Int]

    enum CodingKeys: String, CodingKey { case week, total, days }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        week = Date(timeIntervalSince1970: try c.decode(TimeInterval.self, forKey: .week))
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

/// How the signed-in user watches a repository (`repository-subscription`).
public struct RepositorySubscription: Sendable, Hashable, Codable {
    /// `true` when the user gets notifications for all activity.
    public var isSubscribed: Bool
    /// `true` when the user gets no notifications at all.
    public var isIgnored: Bool
    public var reason: String?
    public var createdAt: Date?
    public var url: URL?
    public var repositoryURL: URL?

    enum CodingKeys: String, CodingKey {
        case reason, url
        case isSubscribed = "subscribed"
        case isIgnored = "ignored"
        case createdAt = "created_at"
        case repositoryURL = "repository_url"
    }
}

/// How to sort starred repositories.
public enum StarSort: String, Sendable, Hashable, CustomStringConvertible {
    /// When the repository was starred.
    case created
    /// When the repository was last pushed to.
    case updated
    public var description: String { rawValue }
}
