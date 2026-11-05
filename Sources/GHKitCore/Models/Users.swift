import Foundation

/// A user or organization as it appears inside other objects (`simple-user`).
public struct SimpleUser: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var login: String
    public var nodeID: String
    public var avatarURL: URL?
    public var htmlURL: URL?
    public var url: URL?
    /// `User`, `Organization`, or `Bot`.
    public var type: String
    public var siteAdmin: Bool?
    public var name: String?
    public var email: String?

    public var isOrganization: Bool { type == "Organization" }

    public init(
        id: Int, login: String, nodeID: String, avatarURL: URL? = nil, htmlURL: URL? = nil, url: URL? = nil,
        type: String = "User", siteAdmin: Bool? = nil, name: String? = nil, email: String? = nil
    ) {
        self.id = id
        self.login = login
        self.nodeID = nodeID
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.url = url
        self.type = type
        self.siteAdmin = siteAdmin
        self.name = name
        self.email = email
    }

    enum CodingKeys: String, CodingKey {
        case id, login, url, type, name, email
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case siteAdmin = "site_admin"
    }
}
