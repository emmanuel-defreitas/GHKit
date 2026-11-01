import Foundation

/// One page of a list endpoint.
public struct Page<Element: Sendable>: Sendable {
    public var items: [Element]
    /// Pass to `GitHubClient.page(_:at:)` to load the next page. `nil` on the last page.
    public var next: PageCursor?
    public var previous: PageCursor?
    public var metadata: ResponseMetadata

    public var hasNextPage: Bool { next != nil }
}

/// An opaque position in a paginated list. It works for both page-number and
/// cursor pagination because it follows GitHub's `Link` header.
public struct PageCursor: Sendable, Hashable {
    public let url: URL
}

extension GitHubClient {
    /// Loads a single page. Use this for "load more" lists in SwiftUI.
    ///
    ///     var page = try await github.page(acme.listRequest())
    ///     if let next = page.next { page = try await github.page(acme.listRequest(), at: next) }
    public func page<Element>(
        _ request: GitHubRequest<[Element]>,
        at cursor: PageCursor? = nil
    ) async throws(GitHubError) -> Page<Element> {
        let target = cursor.map { request.redirected(to: $0.url) } ?? request
        let response = try await send(target)
        let links = response.metadata.links
        return Page(
            items: response.value,
            next: links.next.map(PageCursor.init),
            previous: links.previous.map(PageCursor.init),
            metadata: response.metadata
        )
    }

    /// Every element of a list endpoint, fetched page by page as you iterate.
    public func paginate<Element>(_ request: GitHubRequest<[Element]>) -> Paginated<Element> {
        Paginated(client: self, request: request)
    }
}

/// An async sequence over every element of a list endpoint. Pages load lazily as you iterate.
///
///     for try await project in github.projects(.organization("acme")).list() { … }
///
/// Breaking out of the loop stops loading further pages.
public struct Paginated<Element: Sendable>: AsyncSequence, Sendable {
    public typealias Failure = GitHubError

    let client: GitHubClient
    /// The request for the first page.
    public let request: GitHubRequest<[Element]>

    public func makeAsyncIterator() -> Iterator {
        Iterator(client: client, next: request)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Failure = GitHubError

        let client: GitHubClient
        var next: GitHubRequest<[Element]>?
        var buffer: [Element] = []
        var index = 0

        init(client: GitHubClient, next: GitHubRequest<[Element]>) {
            self.client = client
            self.next = next
        }

        public mutating func next() async throws(GitHubError) -> Element? {
            while index >= buffer.count {
                guard let request = next else { return nil }
                let page = try await client.page(request)
                buffer = page.items
                index = 0
                next = page.next.map { request.redirected(to: $0.url) }
            }
            defer { index += 1 }
            return buffer[index]
        }
    }

    /// The pages themselves, for when you want to show progress per page.
    public var pages: Pages { Pages(client: client, request: request) }

    /// Loads elements into an array, stopping after `limit` if given.
    public func collect(limit: Int? = nil) async throws(GitHubError) -> [Element] {
        var result: [Element] = []
        var iterator = makeAsyncIterator()
        while let element = try await iterator.next() {
            result.append(element)
            if let limit, result.count >= limit { break }
        }
        return result
    }

    /// The first page only.
    public func firstPage() async throws(GitHubError) -> Page<Element> {
        try await client.page(request)
    }

    public struct Pages: AsyncSequence, Sendable {
        public typealias Failure = GitHubError
        let client: GitHubClient
        let request: GitHubRequest<[Element]>

        public func makeAsyncIterator() -> Iterator { Iterator(client: client, next: request) }

        public struct Iterator: AsyncIteratorProtocol {
            public typealias Failure = GitHubError
            let client: GitHubClient
            var next: GitHubRequest<[Element]>?

            public mutating func next() async throws(GitHubError) -> Page<Element>? {
                guard let request = next else { return nil }
                let page = try await client.page(request)
                next = page.next.map { request.redirected(to: $0.url) }
                return page
            }
        }
    }
}

extension GitHubRequest {
    /// A list request whose response wraps the array in an object, such as
    /// `{"total_count": 2, "installations": [...]}`.
    static func wrappedList<Element: Decodable & Sendable>(
        _ path: String,
        key: String,
        query: [URLQueryItem] = []
    ) -> GitHubRequest<[Element]> where Response == [Element] {
        GitHubRequest(method: .get, target: .path(path), query: query) { data in
            let wrapper = try GitHubJSON.decoder().decode([String: LossyArray<Element>].self, from: data)
            return wrapper[key]?.elements ?? []
        }
    }
}

/// Decodes the one array value in a wrapper object and skips the other keys.
struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]?
    init(from decoder: any Decoder) throws {
        elements = try? decoder.singleValueContainer().decode([Element].self)
    }
}
