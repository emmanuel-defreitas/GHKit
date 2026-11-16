import CryptoKit
import Foundation
import Testing

@testable import GHKitCore

/// Known answers from libsodium 1.0 (through PyNaCl) and Python's `hashlib`, plus RFC 8439 for Poly1305.
@Suite("Secret sealer")
struct SecretSealerTests {
    // RFC 7748's X25519 test keys.
    static let aliceSecret = hex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
    static let alicePublic = hex("8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a")
    static let bobSecret = hex("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")
    static let bobPublic = hex("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")

    static func key(_ bytes: [UInt8]) throws -> Curve25519.KeyAgreement.PrivateKey {
        try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: bytes)
    }

    // MARK: Primitives

    @Test(arguments: [
        ("", "ab3b5331a7135ed50d0f182d026e60abdb3646fd51bcf8a3"),
        ("abc", "56a17e38cc371a46b12c32f18e0c61de2a84e9c2555b114e"),
    ])
    func blake2bOfText(_ text: String, _ expected: String) {
        #expect(BLAKE2b.hash(Array(text.utf8), outputLength: 24) == Self.hex(expected))
    }

    @Test func blake2bAcrossBlocks() {
        // 64 bytes fit in one block; 200 need a full block and a partial one.
        #expect(BLAKE2b.hash((0..<64).map { UInt8($0) }, outputLength: 24) == Self.hex("aa054507b4916837a6d2b35b1ce7c525facdb7868ed55a8a"))
        #expect(
            BLAKE2b.hash((0..<200).map { UInt8($0 % 251) }, outputLength: 24)
                == Self.hex("e9183c766451ac26ddd03b280b4b6000802b4b7230c78bb3"))
    }

    @Test func poly1305() {
        let rfcKey = Self.hex("85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b")
        #expect(
            Poly1305.tag(Array("Cryptographic Forum Research Group".utf8), key: rfcKey) == Self.hex("a8061dc1305136c6c22b8baf0c0127a9"))
        let message = (0..<100).map { UInt8($0 * 7 % 256) }
        #expect(Poly1305.tag(message, key: (32..<64).map { UInt8($0) }) == Self.hex("52a146a72f55fce6be243ad46751d9bd"))
        // All-ones key and message, which push every carry.
        #expect(
            Poly1305.tag([UInt8](repeating: 0xff, count: 33), key: [UInt8](repeating: 0xff, count: 32))
                == Self.hex("86fa6a437bf4ec24a274504dc37495bc"))
    }

    @Test func boxKeyMatchesLibsodium() throws {
        let alice = try Self.key(Self.aliceSecret)
        #expect(Array(alice.publicKey.rawRepresentation) == Self.alicePublic)
        // crypto_scalarmult and crypto_box_beforenm.
        let shared = try alice.sharedSecretFromKeyAgreement(with: .init(rawRepresentation: Self.bobPublic))
        #expect(shared.withUnsafeBytes { Array($0) } == Self.hex("4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"))
        #expect(SecretSealer.boxKey(alice, Self.bobPublic) == Self.hex("1b27556473e985d462cd51197a9a46c76009549eac6474f206c4ee0844f68389"))
    }

    /// crypto_secretbox_easy (tag, then ciphertext) for messages around the 32- and 64-byte boundaries.
    @Test(arguments: [
        (0, "102ec2a75fd06e224c1caddcbeaaeb4c"),
        (1, "77818ef03d230e18f98c2d804e9798d0f6"),
        (31, "3550d138050f33675e8f1ffb26b56c45f69439d05832291081214f033cf9d9c323a70ca31a155e90186e403bc50902"),
        (32, "fec402bd61b6a3dedf6ac988b34d6967f69439d05832291081214f033cf9d9c323a70ca31a155e90186e403bc50902b5"),
        (
            64,
            "63a004e585f82e7eba56bc835a0cc274f69439d05832291081214f033cf9d9c323a70ca31a155e90186e403bc50902b550ecbf52aeaa9270e1d538541585921e3431f6d9e0c26dd7ea68997b6c005475"
        ),
        (
            131,
            "9f3abf20d6b3bd9200ababf74b93ea83f69439d05832291081214f033cf9d9c323a70ca31a155e90186e403bc50902b550ecbf52aeaa9270e1d538541585921e3431f6d9e0c26dd7ea68997b6c005475b597525da1bd3f2df317a80508b60c7cb91fd4806bf64259751201da3dd301b9f19d4647afb1602272335e93a52752a319bb13ddcdfbc07fe0847f626d5c9ba28119a2"
        ),
    ])
    func secretbox(_ length: Int, _ expected: String) {
        let key = (100..<132).map { UInt8($0) }
        let nonce = (200..<224).map { UInt8($0) }
        let message = (0..<length).map { UInt8($0 * 13 % 256) }
        let stream = Salsa20.xsalsa20XOR([UInt8](repeating: 0, count: 32) + message, key: key, nonce: nonce)
        let ciphertext = Array(stream[32...])
        #expect(Poly1305.tag(ciphertext, key: Array(stream[..<32])) + ciphertext == Self.hex(expected))
    }

    // MARK: Sealed boxes

    @Test func sealMatchesLibsodium() throws {
        let message = Array("hunter2: a GitHub Actions secret".utf8)
        let sealed = try SecretSealer.seal(message, to: Self.bobPublic, ephemeral: Self.key(Self.aliceSecret))
        #expect(
            sealed
                == Self.hex(
                    "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a4f5ea15fd65b43ee07535e5103571ff0cf72c2b28d8a316bf0076b3d840f613e0d781f15c82f76aa8a1ec1f865d33170"
                ))
    }

    @Test func opensWhatLibsodiumSealed() throws {
        let sealed = Self.hex(
            "37396ecd43e6f720282872960845c1e7ad323f12f98fd584f046b275dd159e23bf8274fc11705d3fd329a806bbf25651f49f8edefa266bc50f554620824bda6e82a1f7"
        )
        #expect(SecretSealer.open(sealed, with: try Self.key(Self.bobSecret)) == Array("sealed by libsodium".utf8))
    }

    @Test func roundTripsAndDetectsTampering() throws {
        let recipient = Curve25519.KeyAgreement.PrivateKey()
        let message = Data((0..<1000).map { UInt8($0 % 256) })
        let sealed = try SecretSealer.seal(message, to: recipient.publicKey.rawRepresentation)
        #expect(sealed.count == message.count + SecretSealer.overhead)
        #expect(SecretSealer.open(Array(sealed), with: recipient) == Array(message))
        // Fresh ephemeral keys, so the same value never seals the same way twice.
        #expect(try SecretSealer.seal(message, to: recipient.publicKey.rawRepresentation) != sealed)

        for index in [0, 40, sealed.count - 1] {
            var tampered = Array(sealed)
            tampered[index] ^= 1
            #expect(SecretSealer.open(tampered, with: recipient) == nil, "Changed byte \(index) wasn't caught")
        }
        #expect(SecretSealer.open(Array(sealed), with: Curve25519.KeyAgreement.PrivateKey()) == nil)
    }

    @Test func encryptsForAPublicKey() throws {
        let recipient = try Self.key(Self.bobSecret)
        let key = SecretsPublicKey(keyID: "568250167242549743", key: recipient.publicKey.rawRepresentation.base64EncodedString())
        let secret = try SecretSealer.encrypt("hunter2", with: key)
        #expect(secret.keyID == "568250167242549743")
        let sealed = try #require(Data(base64Encoded: secret.encryptedValue))
        #expect(SecretSealer.open(Array(sealed), with: recipient) == Array("hunter2".utf8))
        #expect(try GitHubJSON.encoder().encode(secret).count > 0)
    }

    @Test func rejectsKeysThatArentX25519() throws {
        // GitHub's documentation example is a placeholder that decodes to 33 bytes.
        let example = try GitHubJSON.decoder().decode(SecretsPublicKey.self, from: loadFixture("actions-public-key"))
        #expect(example.keyID == "012345678912345678")
        #expect(throws: GitHubError.self) { try SecretSealer.encrypt("x", with: example) }
        #expect(throws: GitHubError.self) { try SecretSealer.encrypt("x", with: SecretsPublicKey(keyID: "1", key: "not base64!")) }
    }

    static func hex(_ text: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            bytes.append(UInt8(text[index..<next], radix: 16)!)
            index = next
        }
        return bytes
    }
}
