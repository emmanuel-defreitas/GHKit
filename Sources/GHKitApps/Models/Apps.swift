import Foundation
import GHKitCore

/// An OAuth token as seen by its app, from the `/applications` token endpoints.
public struct OAuthAuthorization: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var url: URL?
    public var scopes: [String]?
    public var token: String
    public var tokenLastEight: String?
    public var hashedToken: String?
    public var app: App
    public var note: String?
    public var noteURL: URL?
    public var fingerprint: String?
    public var user: SimpleUser?
    public var createdAt: Date
    public var updatedAt: Date
    public var expiresAt: Date?

    public struct App: Sendable, Hashable, Codable {
        public var clientID: String
        public var name: String
        public var url: URL

        enum CodingKeys: String, CodingKey {
            case name, url
            case clientID = "client_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, url, scopes, token, app, note, fingerprint, user
        case tokenLastEight = "token_last_eight"
        case hashedToken = "hashed_token"
        case noteURL = "note_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
    }
}
