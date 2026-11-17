import Foundation

#if canImport(CryptoKit)
    import CryptoKit
#endif

/// Encrypts secret values for GitHub's secrets endpoints, which only accept values sealed to a public key.
///
/// The format is libsodium's sealed box (`crypto_box_seal`): an ephemeral X25519 key, a nonce from
/// BLAKE2b of both public keys, and XSalsa20-Poly1305. GitHub decrypts it with the matching private key,
/// which never leaves GitHub. Each call uses a fresh ephemeral key, so sealing the same value twice gives
/// different results.
///
///     let key = try await github.actions.secretsPublicKey("octocat", "hello-world")
///     let secret = try SecretSealer.encrypt("hunter2", with: key)
public enum SecretSealer {
    /// The bytes a sealed box adds to the plaintext: the ephemeral public key and the Poly1305 tag.
    public static let overhead = 48

    /// `plaintext` sealed to a 32-byte X25519 public key.
    public static func seal(_ plaintext: Data, to publicKey: Data) throws(GitHubError) -> Data {
        #if canImport(CryptoKit)
            Data(try seal(Array(plaintext), to: Array(publicKey), ephemeral: Curve25519.KeyAgreement.PrivateKey()))
        #else
            throw .invalidRequest("Encrypting secrets needs CryptoKit.")
        #endif
    }

    /// A secret value sealed to a repository's, environment's, or organization's public key, ready to send.
    public static func encrypt(_ value: String, with key: SecretsPublicKey) throws(GitHubError) -> EncryptedSecret {
        guard let publicKey = Data(base64Encoded: key.key) else {
            throw .invalidRequest("The secrets public key `\(key.keyID)` isn't valid base64.")
        }
        let sealed = try seal(Data(value.utf8), to: publicKey)
        return EncryptedSecret(encryptedValue: sealed.base64EncodedString(), keyID: key.keyID)
    }

    #if canImport(CryptoKit)
        /// `plaintext` sealed with a given ephemeral key, so tests can compare against fixed output.
        static func seal(
            _ plaintext: [UInt8], to publicKey: [UInt8], ephemeral: Curve25519.KeyAgreement.PrivateKey
        ) throws(GitHubError) -> [UInt8] {
            guard publicKey.count == 32 else {
                throw .invalidRequest("A secrets public key is 32 bytes, not \(publicKey.count).")
            }
            let ephemeralPublicKey = Array(ephemeral.publicKey.rawRepresentation)
            guard let key = boxKey(ephemeral, publicKey) else {
                throw .invalidRequest("The secrets public key isn't a usable X25519 key.")
            }
            let nonce = BLAKE2b.hash(ephemeralPublicKey + publicKey, outputLength: 24)
            // The first 32 bytes of keystream become the Poly1305 key; the rest encrypt the message.
            let stream = Salsa20.xsalsa20XOR([UInt8](repeating: 0, count: 32) + plaintext, key: key, nonce: nonce)
            let ciphertext = Array(stream[32...])
            return ephemeralPublicKey + Poly1305.tag(ciphertext, key: Array(stream[..<32])) + ciphertext
        }

        /// The plaintext of a sealed box, or `nil` if it wasn't sealed to `privateKey`'s public key or was changed.
        ///
        /// GHKit never needs to open a sealed box. This exists to test ``seal(_:to:)`` against libsodium's output.
        static func open(_ sealed: [UInt8], with privateKey: Curve25519.KeyAgreement.PrivateKey) -> [UInt8]? {
            guard sealed.count >= overhead else { return nil }
            let ephemeralPublicKey = Array(sealed[..<32])
            let tag = Array(sealed[32..<48])
            let ciphertext = Array(sealed[48...])
            guard let key = boxKey(privateKey, ephemeralPublicKey) else { return nil }
            let nonce = BLAKE2b.hash(ephemeralPublicKey + privateKey.publicKey.rawRepresentation, outputLength: 24)
            let stream = Salsa20.xsalsa20XOR([UInt8](repeating: 0, count: 32) + ciphertext, key: key, nonce: nonce)
            let expected = Poly1305.tag(ciphertext, key: Array(stream[..<32]))
            // Compare every byte, so the time taken doesn't reveal where the tags differ.
            guard zip(expected, tag).reduce(0, { $0 | ($1.0 ^ $1.1) }) == 0 else { return nil }
            return Array(stream[32...])
        }

        /// `crypto_box_beforenm`: HSalsa20 of the X25519 shared secret, or `nil` for an invalid public key.
        static func boxKey(_ privateKey: Curve25519.KeyAgreement.PrivateKey, _ publicKey: [UInt8]) -> [UInt8]? {
            guard let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey),
                let shared = try? privateKey.sharedSecretFromKeyAgreement(with: publicKey)
            else { return nil }
            return Salsa20.hsalsa20(key: shared.withUnsafeBytes { Array($0) }, nonce: [UInt8](repeating: 0, count: 16))
        }
    #endif
}
