import Foundation
import GHKit
import MCP

/// A tool call's arguments, read with typed getters that explain what's wrong.
///
/// Models don't always send the exact JSON type, so numbers and booleans sent as strings are accepted.
struct ToolArguments: Sendable {
    let values: [String: MCP.Value]

    init(_ values: [String: MCP.Value]?) {
        // Treat explicit nulls as missing, which is how models usually mean them.
        self.values = (values ?? [:]).filter { !$0.value.isNull }
    }

    subscript(key: String) -> MCP.Value? { values[key] }

    // MARK: Strings

    func string(_ key: String) throws(ToolFailure) -> String {
        guard let value = try optionalString(key) else { throw ToolFailure("Missing required argument `\(key)`.") }
        return value
    }

    func optionalString(_ key: String) throws(ToolFailure) -> String? {
        switch values[key] {
        case nil: nil
        case .string(let text)?: text.isEmpty ? nil : text
        // The SDK decodes strings that look like data URLs as data. Hand back the original text.
        case .data(let mimeType, let data)?:
            "data:\(mimeType ?? "text/plain");base64,\(data.base64EncodedString())"
        case .int(let number)?: String(number)
        case .double(let number)?: String(number)
        case .bool(let flag)?: String(flag)
        default: throw ToolFailure("`\(key)` must be a string.")
        }
    }

    func strings(_ key: String) throws(ToolFailure) -> [String] {
        try optionalStrings(key) ?? []
    }

    func optionalStrings(_ key: String) throws(ToolFailure) -> [String]? {
        switch values[key] {
        case nil: return nil
        case .array(let items)?:
            return try items.map { item throws(ToolFailure) in
                guard case .string(let text) = item else { throw ToolFailure("`\(key)` must be an array of strings.") }
                return text
            }
        // A single string where a list was expected.
        case .string(let text)?: return [text]
        default: throw ToolFailure("`\(key)` must be an array of strings.")
        }
    }

    // MARK: Numbers and flags

    func int(_ key: String) throws(ToolFailure) -> Int {
        guard let value = try optionalInt(key) else { throw ToolFailure("Missing required argument `\(key)`.") }
        return value
    }

    func optionalInt(_ key: String) throws(ToolFailure) -> Int? {
        switch values[key] {
        case nil: return nil
        case .int(let number)?: return number
        case .double(let number)?:
            if let exact = Int(exactly: number) { return exact }
        case .string(let text)?:
            if let number = Int(text.trimmingCharacters(in: .whitespaces)) { return number }
        default: break
        }
        throw ToolFailure("`\(key)` must be an integer.")
    }

    func bool(_ key: String, default fallback: Bool) throws(ToolFailure) -> Bool {
        try optionalBool(key) ?? fallback
    }

    func optionalBool(_ key: String) throws(ToolFailure) -> Bool? {
        switch values[key] {
        case nil: return nil
        case .bool(let flag)?: return flag
        case .string("true")?: return true
        case .string("false")?: return false
        default: throw ToolFailure("`\(key)` must be true or false.")
        }
    }

    func object(_ key: String) throws(ToolFailure) -> [String: MCP.Value]? {
        switch values[key] {
        case nil: nil
        case .object(let object)?: object
        default: throw ToolFailure("`\(key)` must be an object.")
        }
    }

    // MARK: Paging

    /// `perPage`, clamped to GitHub's limit of 100.
    var perPage: Int {
        get throws(ToolFailure) { min(max(try optionalInt("perPage") ?? 30, 1), 100) }
    }

    /// The page that `cursor` points at, or `nil` for the first page.
    ///
    /// A cursor is a GitHub API URL, so the client would send its token there. Anything that isn't
    /// on the client's own API server is refused.
    func cursor(for client: GitHubClient) throws(ToolFailure) -> PageCursor? {
        guard let text = try optionalString("cursor") else { return nil }
        let api = client.configuration.server.apiURL
        guard let url = URL(string: text), url.scheme?.lowercased() == api.scheme?.lowercased(),
            url.host()?.lowercased() == api.host()?.lowercased(), url.port == api.port,
            url.path().hasPrefix(api.path())
        else {
            throw ToolFailure("`cursor` must be a `nextCursor` value returned by an earlier call.")
        }
        return PageCursor(url: url)
    }
}
