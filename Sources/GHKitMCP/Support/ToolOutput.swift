import Foundation
import GHKit
import MCP

/// What a tool sends back to the model: compact JSON or a short message.
struct ToolOutput: Sendable, Equatable {
    var text: String

    /// A GHKit model, or anything else `Encodable`, as compact JSON.
    static func json(_ value: some Encodable) throws(ToolFailure) -> ToolOutput {
        do {
            let data = try GitHubJSON.encoder().encode(value)
            return ToolOutput(text: String(decoding: data, as: UTF8.self))
        } catch {
            throw ToolFailure("Couldn't encode the result: \(error)")
        }
    }

    /// A confirmation for calls that return nothing, such as a delete.
    static func message(_ text: String) -> ToolOutput {
        ToolOutput(text: text)
    }

    /// One page of a list, with the cursor for the next one.
    static func page<Element: Encodable & Sendable>(
        _ list: Paginated<Element>,
        _ arguments: ToolArguments,
        _ context: GitHubTool.Context
    ) async throws -> ToolOutput {
        let cursor = try arguments.cursor(for: context.client)
        let page = try await context.client.page(list.request, at: cursor)
        return try .json(ListPage(items: page.items, nextCursor: page.next?.url.absoluteString))
    }

    /// The text cut to `limit` characters, with a note saying so.
    func truncated(to limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit))
            + "\n\n[Truncated: showing \(limit) of \(text.count) characters. Ask for less, for example with a smaller `perPage`.]"
    }
}

/// One page of a list endpoint.
struct ListPage<Element: Encodable>: Encodable {
    let items: [Element]
    /// Pass it back as `cursor` for the next page. Absent on the last page.
    let nextCursor: String?
}
