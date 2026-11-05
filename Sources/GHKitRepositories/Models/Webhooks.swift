import Foundation
import GHKitCore

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
