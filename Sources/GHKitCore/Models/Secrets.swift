import Foundation

/// The public key to encrypt secret values with, for a repository, environment, or organization.
///
/// Encrypt values with ``SecretSealer/encrypt(_:with:)``. GitHub rotates keys, so fetch one before
/// encrypting rather than storing it.
public struct SecretsPublicKey: Sendable, Hashable, Codable {
    /// Send it with the encrypted value, so GitHub knows which key was used.
    public var keyID: String
    /// The X25519 public key, base64-encoded.
    public var key: String

    public init(keyID: String, key: String) {
        self.keyID = keyID
        self.key = key
    }

    enum CodingKeys: String, CodingKey {
        case keyID = "key_id"
        case key
    }
}

/// A secret value sealed to a ``SecretsPublicKey``, as GitHub's endpoints for setting secrets take it.
public struct EncryptedSecret: Sendable, Hashable, Codable {
    /// The sealed value, base64-encoded.
    public var encryptedValue: String
    /// The ``SecretsPublicKey/keyID`` of the key it was sealed to.
    public var keyID: String

    public init(encryptedValue: String, keyID: String) {
        self.encryptedValue = encryptedValue
        self.keyID = keyID
    }

    enum CodingKeys: String, CodingKey {
        case encryptedValue = "encrypted_value"
        case keyID = "key_id"
    }
}
