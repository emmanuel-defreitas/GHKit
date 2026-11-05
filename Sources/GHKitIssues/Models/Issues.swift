import Foundation
import GHKitCore

/// A label to create.
public struct NewLabel: Sendable, Hashable, Encodable {
    /// Emoji are allowed, as text (`:strawberry:`) or as the character.
    public var name: String
    /// A hex color without the `#`, such as `f29513`.
    public var color: String?
    /// Up to 100 characters.
    public var description: String?

    public init(name: String, color: String? = nil, description: String? = nil) {
        self.name = name
        self.color = color
        self.description = description
    }
}

/// Changes to a label. `nil` leaves a field as it is.
public struct LabelUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    public var color: String?
    public var description: String?
    /// Archived labels stay on issues but can't be added to new ones.
    public var isArchived: Bool?

    public init(name: String? = nil, color: String? = nil, description: String? = nil, isArchived: Bool? = nil) {
        self.name = name
        self.color = color
        self.description = description
        self.isArchived = isArchived
    }

    enum CodingKeys: String, CodingKey {
        case color, description
        case name = "new_name"
        case isArchived = "archived"
    }
}

/// How to sort milestones.
public enum MilestoneSort: String, Sendable, Hashable, CustomStringConvertible {
    case dueOn = "due_on"
    /// By the share of closed issues.
    case completeness
    public var description: String { rawValue }
}

/// A milestone to create.
public struct NewMilestone: Sendable, Hashable, Encodable {
    public var title: String
    public var state: IssueState?
    public var description: String?
    public var dueOn: Date?

    public init(title: String, state: IssueState? = nil, description: String? = nil, dueOn: Date? = nil) {
        self.title = title
        self.state = state
        self.description = description
        self.dueOn = dueOn
    }

    enum CodingKeys: String, CodingKey {
        case title, state, description
        case dueOn = "due_on"
    }
}

/// Changes to a milestone. `nil` leaves a field as it is.
public struct MilestoneUpdate: Sendable, Hashable, Encodable {
    public var title: String?
    public var state: IssueState?
    public var description: String?
    public var dueOn: Date?

    public init(title: String? = nil, state: IssueState? = nil, description: String? = nil, dueOn: Date? = nil) {
        self.title = title
        self.state = state
        self.description = description
        self.dueOn = dueOn
    }

    enum CodingKeys: String, CodingKey {
        case title, state, description
        case dueOn = "due_on"
    }
}
