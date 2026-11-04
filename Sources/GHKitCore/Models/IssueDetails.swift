import Foundation

// MARK: - Issue fields

/// The kind of value an issue field holds.
public struct IssueFieldDataType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let text: Self = "text"
    public static let number: Self = "number"
    public static let date: Self = "date"
    public static let singleSelect: Self = "single_select"
    public static let multiSelect: Self = "multi_select"
}

/// An issue field's value on one issue (`issue-field-value`).
public struct IssueFieldValue: Sendable, Hashable, Codable {
    /// A chosen option in a select field.
    public struct Option: Sendable, Hashable, Codable, Identifiable {
        public var id: Int
        public var name: String
        public var color: String?
    }

    public var fieldID: Int
    public var fieldName: String?
    public var nodeID: String
    public var dataType: IssueFieldDataType
    /// Text, a number, or a date string, depending on ``dataType``.
    public var value: JSONValue
    public var singleSelectOption: Option?
    public var multiSelectOptions: [Option]?

    enum CodingKeys: String, CodingKey {
        case value
        case fieldID = "issue_field_id"
        case fieldName = "issue_field_name"
        case nodeID = "node_id"
        case dataType = "data_type"
        case singleSelectOption = "single_select_option"
        case multiSelectOptions = "multi_select_options"
    }
}
