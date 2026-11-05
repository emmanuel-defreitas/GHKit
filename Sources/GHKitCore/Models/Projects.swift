import Foundation

// MARK: - Open enums

/// Defines a string-backed type that keeps unknown values instead of failing to decode.
public protocol OpenEnum: RawRepresentable<String>, Sendable, Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    init(rawValue: String)
}

extension OpenEnum {
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    public var description: String { rawValue }
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
