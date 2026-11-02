import Foundation

@testable import GHKit

// MARK: - Test doubles

/// A canned HTTP response.
struct MockResponse: Sendable {
    var status: Int = 200
    var headers: [String: String] = [:]
    var body: Data = Data()

    static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> MockResponse {
        MockResponse(status: status, headers: headers.merging(["Content-Type": "application/json"]) { a, _ in a }, body: Data(text.utf8))
    }

    static func fixture(_ name: String, status: Int = 200, headers: [String: String] = [:]) -> MockResponse {
        MockResponse(status: status, headers: headers, body: loadFixture(name))
    }

    /// A single-object fixture wrapped in a one-element array, for list endpoints.
    static func fixtureList(_ name: String, status: Int = 200, headers: [String: String] = [:]) -> MockResponse {
        MockResponse(status: status, headers: headers, body: Data("[".utf8) + loadFixture(name) + Data("]".utf8))
    }

    static func noContent() -> MockResponse { MockResponse(status: 204) }
}

/// Answers requests from a handler and records what was sent.
final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let handler: @Sendable (URLRequest, Int) throws -> MockResponse

    /// `handler` gets the request and its zero-based index.
    init(handler: @escaping @Sendable (URLRequest, Int) throws -> MockResponse) {
        self.handler = handler
    }

    /// Replies with `responses` in order, repeating the last one.
    convenience init(_ responses: MockResponse...) {
        self.init { _, index in responses[min(index, responses.count - 1)] }
    }

    var requests: [URLRequest] { lock.withLock { _requests } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = lock.withLock {
            _requests.append(request)
            return _requests.count - 1
        }
        let response = try handler(request, index)
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers)!
        return (response.body, http)
    }
}

/// Records sleeps without waiting.
final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _durations: [Duration] = []
    var durations: [Duration] { lock.withLock { _durations } }
    var sleep: @Sendable (Duration) async throws -> Void {
        { [self] duration in lock.withLock { _durations.append(duration) } }
    }
}

func loadFixture(_ name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! Data(contentsOf: url)
}

func makeClient(
    _ transport: MockTransport,
    authenticator: some Authenticator = TokenAuthenticator(token: "test-token"),
    retryPolicy: RetryPolicy = .none
) -> GitHubClient {
    var client = GitHubClient(
        authenticator: authenticator,
        configuration: GitHubConfiguration(retryPolicy: retryPolicy),
        transport: transport
    )
    client.sleep = { _ in }
    return client
}

extension URLRequest {
    var path: String { url?.path() ?? "" }
    /// The method and path, such as `GET /user`.
    var route: String { "\(httpMethod ?? "GET") \(path)" }
    var queryItems: [String: String] {
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
    }
    var jsonBody: JSONValue? {
        httpBody.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
    }
    var formBody: [String: String] {
        guard let body = httpBody.flatMap({ String(data: $0, encoding: .utf8) }) else { return [:] }
        var result: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map { String($0).removingPercentEncoding ?? String($0) }
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }
}
