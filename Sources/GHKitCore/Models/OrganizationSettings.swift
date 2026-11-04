import Foundation

/// A custom property value: one string, or a list for multi-select properties.
public enum PropertyValue: Sendable, Hashable, Codable, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    case string(String)
    case list([String])

    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: String...) { self = .list(elements) }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([String].self) {
            self = .list(list)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .list(let values): try container.encode(values)
        }
    }
}

/// A property and its value on a repository (`custom-property-value`).
public struct CustomPropertyValue: Sendable, Hashable, Codable {
    public var name: String
    /// `nil` removes the value, so the property falls back to its default.
    public var value: PropertyValue?

    public init(_ name: String, _ value: PropertyValue?) {
        self.name = name
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case name = "property_name"
        case value
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        // GitHub needs an explicit null to unset a value.
        try c.encode(value, forKey: .value)
    }
}
