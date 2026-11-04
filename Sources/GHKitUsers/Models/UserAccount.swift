import Foundation
import GHKitCore

/// Changes to the signed-in user's profile. `nil` leaves a field as it is.
public struct UserProfileUpdate: Sendable, Hashable, Encodable {
    public var name: String?
    /// The publicly visible email. It must be one of your verified addresses.
    public var email: String?
    public var blog: String?
    public var twitterUsername: String?
    public var company: String?
    public var location: String?
    public var hireable: Bool?
    public var bio: String?

    public init(
        name: String? = nil, email: String? = nil, blog: String? = nil, twitterUsername: String? = nil,
        company: String? = nil, location: String? = nil, hireable: Bool? = nil, bio: String? = nil
    ) {
        self.name = name
        self.email = email
        self.blog = blog
        self.twitterUsername = twitterUsername
        self.company = company
        self.location = location
        self.hireable = hireable
        self.bio = bio
    }

    enum CodingKeys: String, CodingKey {
        case name, email, blog, company, location, hireable, bio
        case twitterUsername = "twitter_username"
    }
}

/// An email address on the signed-in user's account.
public struct UserEmail: Sendable, Hashable, Codable, Identifiable {
    public var email: String
    public var primary: Bool
    public var verified: Bool
    /// `public`, `private`, or `nil` for non-primary addresses.
    public var visibility: String?

    public var id: String { email }
}

/// Whether the primary email shows on the profile.
public enum EmailVisibility: String, Sendable, Hashable, Codable {
    case `public`
    case `private`
}

/// A GPG key, or one of its subkeys.
public struct GPGKey: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var name: String?
    public var primaryKeyID: Int?
    public var keyID: String
    public var publicKey: String?
    public var rawKey: String?
    public var emails: [Email]?
    public var subkeys: [GPGKey]?
    public var canSign: Bool?
    public var canEncryptComms: Bool?
    public var canEncryptStorage: Bool?
    public var canCertify: Bool?
    public var revoked: Bool?
    public var createdAt: Date?
    public var expiresAt: Date?

    public struct Email: Sendable, Hashable, Codable {
        public var email: String
        public var verified: Bool
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emails, subkeys, revoked
        case primaryKeyID = "primary_key_id"
        case keyID = "key_id"
        case publicKey = "public_key"
        case rawKey = "raw_key"
        case canSign = "can_sign"
        case canEncryptComms = "can_encrypt_comms"
        case canEncryptStorage = "can_encrypt_storage"
        case canCertify = "can_certify"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

/// An SSH key for authentication (`key`), or a user's public key (`key-simple`).
///
/// Only keys on the signed-in user's account have a title, URL, and verification status.
public struct SSHKey: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var key: String
    public var title: String?
    public var url: URL?
    public var verified: Bool?
    public var readOnly: Bool?
    public var createdAt: Date?
    public var lastUsed: Date?

    enum CodingKeys: String, CodingKey {
        case id, key, title, url, verified
        case readOnly = "read_only"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }
}

/// An SSH key used to sign commits.
public struct SSHSigningKey: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var key: String
    public var title: String?
    public var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, key, title
        case createdAt = "created_at"
    }
}

/// A linked social profile, such as Mastodon or LinkedIn.
public struct SocialAccount: Sendable, Hashable, Codable, Identifiable {
    /// `twitter`, `linkedin`, `mastodon`, `generic`, and others.
    public var provider: String
    public var url: URL

    public var id: URL { url }
}

/// One line of a user's hovercard, such as "Owns this repository".
public struct HovercardContext: Sendable, Hashable, Codable {
    public var message: String
    /// The Octicon name GitHub shows next to the message.
    public var octicon: String
}

/// What a hovercard is shown about, for extra context lines.
public enum HovercardSubject: Sendable, Hashable {
    case organization(id: Int)
    case repository(id: Int)
    case issue(id: Int)
    case pullRequest(id: Int)

    var query: [URLQueryItem] {
        let (type, id): (String, Int) =
            switch self {
            case .organization(let id): ("organization", id)
            case .repository(let id): ("repository", id)
            case .issue(let id): ("issue", id)
            case .pullRequest(let id): ("pull_request", id)
            }
        return [URLQueryItem(name: "subject_type", value: type), URLQueryItem(name: "subject_id", value: String(id))]
    }
}
