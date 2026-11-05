import Foundation
import GHKitCore

/// An issue or pull request to add to a project.
public struct ProjectItemContentReference: Sendable, Hashable, Encodable {
    public enum Kind: String, Sendable, Hashable, Encodable {
        case issue = "Issue"
        case pullRequest = "PullRequest"
    }

    public enum Locator: Sendable, Hashable {
        case id(Int)
        case number(owner: String, repository: String, number: Int)
    }

    public var kind: Kind
    public var locator: Locator

    public init(kind: Kind, locator: Locator) {
        self.kind = kind
        self.locator = locator
    }

    /// An issue by its database ID (not its number).
    public static func issue(id: Int) -> Self { Self(kind: .issue, locator: .id(id)) }
    /// A pull request by its database ID (not its number).
    public static func pullRequest(id: Int) -> Self { Self(kind: .pullRequest, locator: .id(id)) }
    /// An issue by repository and number.
    public static func issue(owner: String, repository: String, number: Int) -> Self {
        Self(kind: .issue, locator: .number(owner: owner, repository: repository, number: number))
    }
    /// A pull request by repository and number.
    public static func pullRequest(owner: String, repository: String, number: Int) -> Self {
        Self(kind: .pullRequest, locator: .number(owner: owner, repository: repository, number: number))
    }

    private enum CodingKeys: String, CodingKey { case type, id, owner, repo, number }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .type)
        switch locator {
        case .id(let id):
            try c.encode(id, forKey: .id)
        case .number(let owner, let repository, let number):
            try c.encode(owner, forKey: .owner)
            try c.encode(repository, forKey: .repo)
            try c.encode(number, forKey: .number)
        }
    }
}

/// A new value for an item's field.
public enum ProjectFieldValue: Sendable, Hashable, Encodable {
    case text(String)
    case number(Double)
    case date(CalendarDate)
    /// A single-select option, by option ID (see ``ProjectField/option(named:)``).
    case singleSelect(optionID: String)
    /// An iteration, by iteration ID.
    case iteration(id: String)
    /// Clears the field.
    case clear

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let value): try c.encode(value)
        case .number(let value): try c.encode(value)
        case .date(let value): try c.encode(value)
        case .singleSelect(let id), .iteration(let id): try c.encode(id)
        case .clear: try c.encodeNil()
        }
    }
}

/// One field change in an item update.
public struct ProjectFieldUpdate: Sendable, Hashable, Encodable {
    public var fieldID: Int
    public var value: ProjectFieldValue

    public init(fieldID: Int, value: ProjectFieldValue) {
        self.fieldID = fieldID
        self.value = value
    }

    /// Sets `field` to `value`.
    public static func set(_ field: ProjectField, to value: ProjectFieldValue) -> Self {
        Self(fieldID: field.id, value: value)
    }

    private enum CodingKeys: String, CodingKey { case id, value }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fieldID, forKey: .id)
        try c.encode(value, forKey: .value)  // `.clear` must be sent as an explicit null
    }
}

/// A field to add to a project.
public enum NewProjectField: Sendable, Hashable, Encodable {
    case text(name: String)
    case number(name: String)
    case date(name: String)
    case singleSelect(name: String, options: [NewSingleSelectOption])
    case iteration(name: String, configuration: NewIterationConfiguration)
    /// Adds an organization issue field to the project.
    case issueField(id: Int)

    private enum CodingKeys: String, CodingKey {
        case name
        case dataType = "data_type"
        case singleSelectOptions = "single_select_options"
        case iterationConfiguration = "iteration_configuration"
        case issueFieldID = "issue_field_id"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let name):
            try c.encode(name, forKey: .name)
            try c.encode("text", forKey: .dataType)
        case .number(let name):
            try c.encode(name, forKey: .name)
            try c.encode("number", forKey: .dataType)
        case .date(let name):
            try c.encode(name, forKey: .name)
            try c.encode("date", forKey: .dataType)
        case .singleSelect(let name, let options):
            try c.encode(name, forKey: .name)
            try c.encode("single_select", forKey: .dataType)
            try c.encode(options, forKey: .singleSelectOptions)
        case .iteration(let name, let configuration):
            try c.encode(name, forKey: .name)
            try c.encode("iteration", forKey: .dataType)
            try c.encode(configuration, forKey: .iterationConfiguration)
        case .issueField(let id):
            try c.encode(id, forKey: .issueFieldID)
        }
    }
}

/// A single-select option to create.
public struct NewSingleSelectOption: Sendable, Hashable, Encodable {
    public var name: String
    public var color: ProjectColor
    public var description: String

    public init(_ name: String, color: ProjectColor = .gray, description: String = "") {
        self.name = name
        self.color = color
        self.description = description
    }
}

/// Settings for a new iteration field.
public struct NewIterationConfiguration: Sendable, Hashable, Encodable {
    public var startDate: CalendarDate
    /// Default iteration length in days.
    public var duration: Int
    public var iterations: [NewIteration]

    public init(startDate: CalendarDate, duration: Int = 14, iterations: [NewIteration] = []) {
        self.startDate = startDate
        self.duration = duration
        self.iterations = iterations
    }

    enum CodingKeys: String, CodingKey {
        case duration, iterations
        case startDate = "start_date"
    }
}

/// One iteration to create.
public struct NewIteration: Sendable, Hashable, Encodable {
    public var title: String
    public var startDate: CalendarDate
    public var duration: Int

    public init(title: String, startDate: CalendarDate, duration: Int = 14) {
        self.title = title
        self.startDate = startDate
        self.duration = duration
    }

    enum CodingKeys: String, CodingKey {
        case title, duration
        case startDate = "start_date"
    }
}

/// A view to create.
public struct NewProjectView: Sendable, Hashable, Encodable {
    public var name: String
    public var layout: ProjectViewLayout
    /// Filter query, such as `is:issue is:open`.
    public var filter: String?
    /// Field IDs to show. Not used by roadmap views.
    public var visibleFields: [Int]?
    public var sortBy: [ProjectViewSort]?
    /// Field to group rows by.
    public var groupByField: Int?
    /// Field to use as board columns.
    public var columnField: Int?

    public init(
        name: String,
        layout: ProjectViewLayout = .table,
        filter: String? = nil,
        visibleFields: [Int]? = nil,
        sortBy: [ProjectViewSort]? = nil,
        groupByField: Int? = nil,
        columnField: Int? = nil
    ) {
        self.name = name
        self.layout = layout
        self.filter = filter
        self.visibleFields = visibleFields
        self.sortBy = sortBy
        self.groupByField = groupByField
        self.columnField = columnField
    }

    private enum CodingKeys: String, CodingKey {
        case name, layout, filter
        case visibleFields = "visible_fields"
        case sortBy = "sort_by"
        case groupBy = "group_by"
        case verticalGroupBy = "vertical_group_by"
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(layout, forKey: .layout)
        try c.encodeIfPresent(filter, forKey: .filter)
        try c.encodeIfPresent(visibleFields, forKey: .visibleFields)
        try c.encodeIfPresent(sortBy, forKey: .sortBy)
        try c.encodeIfPresent(groupByField.map { [$0] }, forKey: .groupBy)
        try c.encodeIfPresent(columnField.map { [$0] }, forKey: .verticalGroupBy)
    }
}

/// A collaborator change for ``ProjectsAPI/updateCollaborators(of:_:)``.
public struct ProjectCollaborator: Sendable, Hashable, Encodable {
    public enum Role: String, Sendable, Hashable, Encodable {
        case reader = "READER"
        case writer = "WRITER"
        case admin = "ADMIN"
        /// Removes the collaborator.
        case none = "NONE"
    }

    var userId: String?
    var teamId: String?
    public var role: Role

    /// A user, by node ID.
    public static func user(nodeID: String, role: Role) -> Self { Self(userId: nodeID, teamId: nil, role: role) }
    /// A team, by node ID.
    public static func team(nodeID: String, role: Role) -> Self { Self(userId: nil, teamId: nodeID, role: role) }
}
