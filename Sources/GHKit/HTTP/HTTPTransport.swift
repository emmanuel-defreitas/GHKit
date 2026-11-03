import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Sends raw HTTP requests. Swap it out to add logging, caching, or test doubles.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The default transport, backed by `URLSession`.
public struct URLSessionTransport: HTTPTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #if canImport(FoundationNetworking)
            let (data, response) = try await session.data(for: request)
        #else
            let (data, response) = try await session.data(for: request, delegate: RedirectPolicy.shared)
        #endif
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

/// Keeps credentials on GitHub's hosts. Downloads such as release assets redirect to storage
/// hosts that reject requests carrying an `Authorization` header.
final class RedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = RedirectPolicy()

    /// The request to follow: `redirect` without credentials when it leaves the original host.
    static func follow(_ redirect: URLRequest, from original: URLRequest?) -> URLRequest {
        guard let from = original?.url?.host(), let to = redirect.url?.host(), from.lowercased() != to.lowercased() else {
            return redirect
        }
        var request = redirect
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        return request
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(Self.follow(request, from: task.originalRequest))
    }
}

public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    /// Methods that are safe to retry after a server error.
    var isIdempotent: Bool { self != .post && self != .patch }
}
