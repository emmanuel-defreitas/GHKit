import Foundation

// Webhook types shared by repository and organization webhooks.

/// A repository webhook (`hook`).
public struct RepositoryWebhook: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// `web`, or the name of a legacy service.
    public var name: String
    /// Event names, such as `push`. `*` means every event.
    public var events: [String]
    public var active: Bool
    public var config: WebhookConfiguration
    public var url: URL?
    public var testURL: URL?
    public var pingURL: URL?
    public var deliveriesURL: URL?
    /// The outcome of the most recent delivery.
    public var lastResponse: WebhookLastResponse?
    /// Always `Repository`.
    public var type: String?
    public var createdAt: Date?
    public var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, events, active, config, url, type
        case testURL = "test_url"
        case pingURL = "ping_url"
        case deliveriesURL = "deliveries_url"
        case lastResponse = "last_response"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// The outcome of a webhook's most recent delivery (`hook-response`).
public struct WebhookLastResponse: Sendable, Hashable, Codable {
    /// The HTTP status code, or `nil` before the first delivery.
    public var code: Int?
    /// Such as `active` or `unused`.
    public var status: String?
    public var message: String?
}

/// Where and how a webhook delivers payloads (`webhook-config`). `nil` fields are left as they are.
public struct WebhookConfiguration: Sendable, Hashable, Codable {
    public var url: URL?
    public var contentType: WebhookContentType?
    /// Signs deliveries with `X-Hub-Signature-256`. GitHub returns it masked as `********`.
    public var secret: String?
    /// Skips TLS certificate checks. Avoid this; it allows man-in-the-middle attacks.
    public var insecureSSL: Bool?

    public init(url: URL? = nil, contentType: WebhookContentType? = nil, secret: String? = nil, insecureSSL: Bool? = nil) {
        self.url = url
        self.contentType = contentType
        self.secret = secret
        self.insecureSSL = insecureSSL
    }

    enum CodingKeys: String, CodingKey {
        case url, secret
        case contentType = "content_type"
        case insecureSSL = "insecure_ssl"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        contentType = try c.decodeIfPresent(WebhookContentType.self, forKey: .contentType)
        secret = try c.decodeIfPresent(String.self, forKey: .secret)
        // GitHub sends "0"/"1" as a string or a number.
        if let flag = try? c.decodeIfPresent(String.self, forKey: .insecureSSL) {
            insecureSSL = flag == "1"
        } else if let flag = try? c.decodeIfPresent(Int.self, forKey: .insecureSSL) {
            insecureSSL = flag == 1
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(contentType, forKey: .contentType)
        try c.encodeIfPresent(secret, forKey: .secret)
        try c.encodeIfPresent(insecureSSL.map { $0 ? "1" : "0" }, forKey: .insecureSSL)
    }
}

/// How webhook payloads are serialized.
public struct WebhookContentType: OpenEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let json: Self = "json"
    /// `application/x-www-form-urlencoded`, GitHub's default.
    public static let form: Self = "form"
}

/// A webhook to create.
public struct NewWebhook: Sendable, Hashable, Encodable {
    public var config: WebhookConfiguration
    /// Event names, such as `push` or `pull_request`. `["*"]` subscribes to everything.
    public var events: [String]
    public var active: Bool

    public init(config: WebhookConfiguration, events: [String] = ["push"], active: Bool = true) {
        self.config = config
        self.events = events
        self.active = active
    }

    enum CodingKeys: String, CodingKey { case name, config, events, active }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("web", forKey: .name)
        try c.encode(config, forKey: .config)
        try c.encode(events, forKey: .events)
        try c.encode(active, forKey: .active)
    }
}

/// Changes to a webhook. `nil` leaves a field as it is.
public struct WebhookUpdate: Sendable, Hashable, Encodable {
    public var config: WebhookConfiguration?
    /// Replaces every event the webhook subscribes to.
    public var events: [String]?
    /// Events to subscribe to as well. Repository webhooks only.
    public var addEvents: [String]?
    /// Events to stop subscribing to. Repository webhooks only.
    public var removeEvents: [String]?
    public var active: Bool?

    public init(
        config: WebhookConfiguration? = nil, events: [String]? = nil, addEvents: [String]? = nil, removeEvents: [String]? = nil,
        active: Bool? = nil
    ) {
        self.config = config
        self.events = events
        self.addEvents = addEvents
        self.removeEvents = removeEvents
        self.active = active
    }

    enum CodingKeys: String, CodingKey {
        case config, events, active
        case addEvents = "add_events"
        case removeEvents = "remove_events"
    }
}

/// One attempt to deliver a webhook payload (`hook-delivery-item`).
public struct WebhookDelivery: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    /// Shared by a delivery and its redeliveries.
    public var guid: String
    public var deliveredAt: Date?
    public var redelivery: Bool
    /// Seconds.
    public var duration: Double?
    /// Such as `OK` or `failed to connect`.
    public var status: String
    public var statusCode: Int
    public var event: String
    public var action: String?
    public var installationID: Int?
    public var repositoryID: Int?
    public var throttledAt: Date?

    /// Whether the status code is 200–399, which GitHub counts as a success.
    public var succeeded: Bool { (200..<400).contains(statusCode) }

    enum CodingKeys: String, CodingKey {
        case id, guid, redelivery, duration, status, event, action
        case deliveredAt = "delivered_at"
        case statusCode = "status_code"
        case installationID = "installation_id"
        case repositoryID = "repository_id"
        case throttledAt = "throttled_at"
    }
}

/// A delivery with the full request and response (`hook-delivery`).
public struct WebhookDeliveryDetail: Sendable, Hashable, Codable, Identifiable {
    public var delivery: WebhookDelivery
    public var url: URL?
    public var request: Request
    public var response: Response

    public var id: Int { delivery.id }

    public struct Request: Sendable, Hashable, Codable {
        public var headers: [String: String]?
        public var payload: JSONValue?
    }

    public struct Response: Sendable, Hashable, Codable {
        public var headers: [String: String]?
        public var payload: String?
    }

    enum CodingKeys: String, CodingKey { case url, request, response }

    public init(from decoder: any Decoder) throws {
        delivery = try WebhookDelivery(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url).flatMap(URL.init(string:))
        request = try c.decode(Request.self, forKey: .request)
        response = try c.decode(Response.self, forKey: .response)
    }

    public func encode(to encoder: any Encoder) throws {
        try delivery.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encode(request, forKey: .request)
        try c.encode(response, forKey: .response)
    }
}

/// Narrows webhook deliveries by outcome.
public enum WebhookDeliveryStatus: String, Sendable, Hashable, CustomStringConvertible {
    case success, failure
    public var description: String { rawValue }
}
