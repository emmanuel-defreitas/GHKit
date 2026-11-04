import Foundation
import GHKitCore

// MARK: - Owner

/// Who owns a project. Projects belong to an organization or a user, never a repository.
public enum ProjectOwner: Sendable, Hashable, CustomStringConvertible {
    case organization(String)
    case user(String)

    public var login: String {
        switch self {
        case .organization(let login), .user(let login): login
        }
    }

    /// `/orgs/{org}` or `/users/{username}`
    var pathPrefix: String {
        switch self {
        case .organization(let login): "/orgs/\(escape(login))"
        case .user(let login): "/users/\(escape(login))"
        }
    }

    /// The owner of a project returned by the API.
    public init(_ account: SimpleUser) {
        self = account.isOrganization ? .organization(account.login) : .user(account.login)
    }

    public var description: String {
        switch self {
        case .organization(let login): "org:\(login)"
        case .user(let login): "user:\(login)"
        }
    }
}

/// Whether a project is open or closed.
public struct ProjectState: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let open: Self = "open"
    public static let closed: Self = "closed"
}

/// What a project item tracks.
public struct ProjectItemContentType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let issue: Self = "Issue"
    public static let pullRequest: Self = "PullRequest"
    public static let draftIssue: Self = "DraftIssue"
}

/// A project field's data type.
public struct ProjectFieldDataType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    // Fields you can create
    public static let text: Self = "text"
    public static let number: Self = "number"
    public static let date: Self = "date"
    public static let singleSelect: Self = "single_select"
    public static let iteration: Self = "iteration"
    // Built-in fields
    public static let title: Self = "title"
    public static let assignees: Self = "assignees"
    public static let labels: Self = "labels"
    public static let milestone: Self = "milestone"
    public static let repository: Self = "repository"
    public static let reviewers: Self = "reviewers"
    public static let linkedPullRequests: Self = "linked_pull_requests"
    public static let issueType: Self = "issue_type"
    public static let parentIssue: Self = "parent_issue"
    public static let subIssuesProgress: Self = "sub_issues_progress"
}

/// A single-select option color.
public struct ProjectColor: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let blue: Self = "BLUE"
    public static let gray: Self = "GRAY"
    public static let green: Self = "GREEN"
    public static let orange: Self = "ORANGE"
    public static let pink: Self = "PINK"
    public static let purple: Self = "PURPLE"
    public static let red: Self = "RED"
    public static let yellow: Self = "YELLOW"
}

/// A view's layout.
public struct ProjectViewLayout: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let table: Self = "table"
    public static let board: Self = "board"
    public static let roadmap: Self = "roadmap"
}

/// The health reported in a project status update.
public struct ProjectStatus: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inactive: Self = "INACTIVE"
    public static let onTrack: Self = "ON_TRACK"
    public static let atRisk: Self = "AT_RISK"
    public static let offTrack: Self = "OFF_TRACK"
    public static let complete: Self = "COMPLETE"
}

// MARK: - Project

/// A project (Projects v2).
public struct Project: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// Global ID, used by GraphQL mutations.
    public var nodeID: String
    public var number: Int
    public var title: String
    public var description: String?
    public var shortDescription: String?
    public var owner: SimpleUser
    public var creator: SimpleUser
    public var isPublic: Bool
    public var state: ProjectState?
    public var isTemplate: Bool?
    public var latestStatusUpdate: ProjectStatusUpdate?
    public var createdAt: Date
    public var updatedAt: Date
    public var closedAt: Date?
    public var deletedAt: Date?
    public var deletedBy: SimpleUser?

    public var isClosed: Bool { state == .closed || closedAt != nil }

    /// The owner, in the form the ``ProjectsAPI`` methods take.
    public var projectOwner: ProjectOwner { ProjectOwner(owner) }

    /// The project's page on GitHub.
    public func webURL(server: GitHubServer = .dotCom) -> URL {
        let kind = owner.isOrganization ? "orgs" : "users"
        return server.webURL.appending(path: "\(kind)/\(owner.login)/projects/\(number)")
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, owner, creator, state
        case nodeID = "node_id"
        case shortDescription = "short_description"
        case isPublic = "public"
        case isTemplate = "is_template"
        case latestStatusUpdate = "latest_status_update"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case deletedAt = "deleted_at"
        case deletedBy = "deleted_by"
    }
}

/// A project status update: health, dates, and a note.
public struct ProjectStatusUpdate: Sendable, Hashable, Codable, Identifiable {
    /// Database ID. Missing on updates that came from GraphQL without one.
    public var databaseID: Int?
    public var nodeID: String
    public var projectNodeID: String?
    public var creator: SimpleUser?
    public var status: ProjectStatus?
    public var startDate: CalendarDate?
    public var targetDate: CalendarDate?
    public var body: String?
    public var createdAt: Date
    public var updatedAt: Date

    public var id: String { nodeID }

    public init(
        databaseID: Int? = nil, nodeID: String, projectNodeID: String? = nil, creator: SimpleUser? = nil,
        status: ProjectStatus? = nil, startDate: CalendarDate? = nil, targetDate: CalendarDate? = nil,
        body: String? = nil, createdAt: Date, updatedAt: Date
    ) {
        self.databaseID = databaseID
        self.nodeID = nodeID
        self.projectNodeID = projectNodeID
        self.creator = creator
        self.status = status
        self.startDate = startDate
        self.targetDate = targetDate
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case creator, status, body
        case databaseID = "id"
        case nodeID = "node_id"
        case projectNodeID = "project_node_id"
        case startDate = "start_date"
        case targetDate = "target_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Fields

/// A field (column) in a project.
public struct ProjectField: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    /// Set when the field mirrors an organization issue field.
    public var issueFieldID: Int?
    public var name: String
    public var dataType: ProjectFieldDataType
    /// Choices for single-select fields.
    public var options: [ProjectSingleSelectOption]?
    /// Settings for iteration fields.
    public var configuration: ProjectIterationConfiguration?
    public var projectURL: URL?
    public var createdAt: Date
    public var updatedAt: Date

    /// The single-select option with this name, ignoring case.
    public func option(named name: String) -> ProjectSingleSelectOption? {
        options?.first { $0.name.raw.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The iteration that contains `date`, if any.
    public func iteration(containing date: CalendarDate) -> ProjectIteration? {
        configuration?.iterations?.first { $0.contains(date) }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, options, configuration
        case nodeID = "node_id"
        case issueFieldID = "issue_field_id"
        case dataType = "data_type"
        case projectURL = "project_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// One choice in a single-select field.
public struct ProjectSingleSelectOption: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var name: RichText
    public var description: RichText?
    public var color: ProjectColor?
}

/// An iteration field's settings.
public struct ProjectIterationConfiguration: Sendable, Hashable, Codable {
    /// Day of the week iterations start on (1 = Monday).
    public var startDay: Int?
    /// Default iteration length in days.
    public var duration: Int?
    public var iterations: [ProjectIteration]?

    enum CodingKeys: String, CodingKey {
        case duration, iterations
        case startDay = "start_day"
    }
}

/// One iteration (sprint) of an iteration field.
public struct ProjectIteration: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var title: RichText
    public var startDate: CalendarDate
    /// Length in days.
    public var duration: Int
    public var completed: Bool?

    /// The first day after the iteration.
    public var endDate: CalendarDate {
        guard let start = startDate.date(in: .gmt) else { return startDate }
        return CalendarDate(start.addingTimeInterval(TimeInterval(duration) * 86_400), timeZone: .gmt)
    }

    public func contains(_ date: CalendarDate) -> Bool {
        date >= startDate && date < endDate
    }

    enum CodingKeys: String, CodingKey {
        case id, title, duration, completed
        case startDate = "start_date"
    }
}

// MARK: - Items

/// An issue, pull request, or draft issue in a project.
public struct ProjectItem: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var nodeID: String?
    public var contentType: ProjectItemContentType
    public var content: ProjectItemContent?
    public var creator: SimpleUser?
    /// Field values. The REST API returns the Title field plus any field IDs you request.
    public var fields: [ProjectItemFieldValue]?
    public var projectURL: URL?
    public var itemURL: URL?
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    public var isArchived: Bool { archivedAt != nil }

    /// The value for a field, by field ID.
    public func value(forField fieldID: Int) -> ProjectItemFieldValue? {
        fields?.first { $0.id == fieldID }
    }

    /// The value for a field, by name, ignoring case.
    public func value(forFieldNamed name: String) -> ProjectItemFieldValue? {
        fields?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The item's title, from its content or its Title field.
    public var title: String? {
        content?.title ?? fields?.first { $0.dataType == .title }?.text
    }

    enum CodingKeys: String, CodingKey {
        case id, content, creator, fields
        case nodeID = "node_id"
        case contentType = "content_type"
        case projectURL = "project_url"
        case itemURL = "item_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

/// The issue, pull request, or draft issue behind a project item.
///
/// Common properties are typed. Everything GitHub sent is in ``raw``.
public struct ProjectItemContent: Sendable, Hashable, Codable {
    public var id: Int?
    public var nodeID: String?
    public var number: Int?
    public var title: String?
    public var body: String?
    /// `open` or `closed` for issues and pull requests.
    public var state: String?
    public var htmlURL: URL?
    public var url: URL?
    public var repositoryURL: URL?
    /// The author.
    public var user: SimpleUser?
    public var assignees: [SimpleUser]?
    public var createdAt: Date?
    public var updatedAt: Date?
    /// The full payload.
    public var raw: JSONValue

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, url, user, assignees
        case nodeID = "node_id"
        case htmlURL = "html_url"
        case repositoryURL = "repository_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(from decoder: any Decoder) throws {
        raw = try JSONValue(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Content varies by type, so read each property leniently.
        id = try? c.decodeIfPresent(Int.self, forKey: .id)
        nodeID = try? c.decodeIfPresent(String.self, forKey: .nodeID)
        number = try? c.decodeIfPresent(Int.self, forKey: .number)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        body = try? c.decodeIfPresent(String.self, forKey: .body)
        state = try? c.decodeIfPresent(String.self, forKey: .state)
        htmlURL = try? c.decodeIfPresent(URL.self, forKey: .htmlURL)
        url = try? c.decodeIfPresent(URL.self, forKey: .url)
        repositoryURL = try? c.decodeIfPresent(URL.self, forKey: .repositoryURL)
        user = try? c.decodeIfPresent(SimpleUser.self, forKey: .user)
        assignees = try? c.decodeIfPresent([SimpleUser].self, forKey: .assignees)
        createdAt = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try? c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: any Encoder) throws {
        try raw.encode(to: encoder)
    }

    /// Decodes the full payload as your own type.
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try raw.decode(as: type)
    }
}

/// A field value on an item.
public struct ProjectItemFieldValue: Sendable, Hashable, Codable, Identifiable {
    /// The field's ID.
    public var id: Int
    public var name: String
    public var dataType: ProjectFieldDataType
    /// The raw value. Its shape depends on ``dataType``.
    public var value: JSONValue?

    /// Text fields, and the Title field's text.
    public var text: String? {
        value?.stringValue ?? value?["raw"]?.stringValue
    }

    public var number: Double? { value?.doubleValue }

    public var date: CalendarDate? { value?.stringValue.flatMap { CalendarDate(String($0.prefix(10))) } }

    /// The selected option's ID, for single-select fields.
    public var singleSelectOptionID: String? {
        dataType == .singleSelect ? value?["id"]?.stringValue : nil
    }

    /// The selected option's name, for single-select fields.
    public var singleSelectOptionName: String? {
        dataType == .singleSelect ? (value?["name"]?["raw"]?.stringValue ?? value?["name"]?.stringValue) : nil
    }

    /// The iteration's ID, for iteration fields.
    public var iterationID: String? {
        dataType == .iteration ? value?["id"]?.stringValue : nil
    }

    /// The iteration's title, for iteration fields.
    public var iterationTitle: String? {
        dataType == .iteration ? (value?["title"]?["raw"]?.stringValue ?? value?["title"]?.stringValue) : nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, value
        case dataType = "data_type"
    }
}

// MARK: - Views

/// A saved view (table, board, or roadmap) of a project.
public struct ProjectView: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var number: Int
    public var nodeID: String
    public var name: String
    public var layout: ProjectViewLayout
    public var filter: String?
    public var visibleFields: [Int]
    public var sortBy: [ProjectViewSort]
    public var groupBy: [Int]
    public var verticalGroupBy: [Int]
    public var creator: SimpleUser?
    public var projectURL: URL?
    public var htmlURL: URL?
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, number, name, layout, filter, creator
        case nodeID = "node_id"
        case visibleFields = "visible_fields"
        case sortBy = "sort_by"
        case groupBy = "group_by"
        case verticalGroupBy = "vertical_group_by"
        case projectURL = "project_url"
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// One sort rule in a view. On the wire it's a pair: `[field_id, "asc"]`.
public struct ProjectViewSort: Sendable, Hashable, Codable {
    public enum Direction: String, Sendable, Hashable, Codable {
        case ascending = "asc"
        case descending = "desc"
    }

    public var fieldID: Int
    public var direction: Direction

    public init(fieldID: Int, direction: Direction = .ascending) {
        self.fieldID = fieldID
        self.direction = direction
    }

    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        fieldID = try c.decode(Int.self)
        direction = Direction(rawValue: try c.decode(String.self).lowercased()) ?? .ascending
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(fieldID)
        try c.encode(direction.rawValue)
    }
}
