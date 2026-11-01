import Foundation

/// A calendar date without a time, encoded as `YYYY-MM-DD`.
///
/// GitHub uses plain dates for iteration start dates and status update dates.
public struct CalendarDate: Sendable, Hashable, Comparable, Codable, LosslessStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar day that contains `date` in the given time zone.
    public init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public init?(_ description: String) {
        let parts = description.split(separator: "-")
        guard parts.count == 3,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public var description: String {
        let y = String(year).leftPadded(to: 4)
        let m = String(month).leftPadded(to: 2)
        let d = String(day).leftPadded(to: 2)
        return "\(y)-\(m)-\(d)"
    }

    /// Midnight at the start of this day in the given time zone.
    public func date(in timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        // Tolerate full timestamps by keeping only the date part.
        guard let value = CalendarDate(String(raw.prefix(10))) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// Text that GitHub returns both as raw Markdown and as rendered HTML.
///
/// Decodes from either `{"raw": …, "html": …}` or a plain string.
public struct RichText: Sendable, Hashable, Codable, CustomStringConvertible {
    public var raw: String
    public var html: String

    public init(raw: String, html: String? = nil) {
        self.raw = raw
        self.html = html ?? raw
    }

    public var description: String { raw }

    private enum CodingKeys: String, CodingKey { case raw, html }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let string = try? single.decode(String.self) {
            self.init(raw: string)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(String.self, forKey: .raw)
        self.init(raw: raw, html: try container.decodeIfPresent(String.self, forKey: .html))
    }
}

extension String {
    fileprivate func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
