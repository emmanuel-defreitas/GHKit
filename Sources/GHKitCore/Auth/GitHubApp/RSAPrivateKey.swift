import Foundation

#if canImport(Security)
    import Security
#endif

/// A GitHub App's RSA private key, from the `.pem` file GitHub gives you.
///
/// Accepts PKCS#1 (`BEGIN RSA PRIVATE KEY`, GitHub's format) and PKCS#8 (`BEGIN PRIVATE KEY`).
/// Keep this key on a server. Shipping it in an app lets anyone act as your app.
public struct RSAPrivateKey: Sendable, Hashable {
    /// The PKCS#1 DER bytes.
    let der: Data

    public init(pem: String) throws(GitHubError) {
        let body =
            pem
            .split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        guard let data = Data(base64Encoded: body) else {
            throw .authentication("The private key isn't valid PEM.")
        }
        if pem.contains("BEGIN RSA PRIVATE KEY") {
            self.der = data
        } else {
            self.der = try Self.unwrapPKCS8(data)
        }
    }

    public init(der: Data) {
        self.der = der
    }

    #if canImport(Security)
        /// Signs `message` with RSASSA-PKCS1-v1_5 SHA-256, as JWT's `RS256` requires.
        func signRS256(_ message: Data) throws(GitHubError) -> Data {
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            ]
            var error: Unmanaged<CFError>?
            guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error) else {
                throw .authentication("Couldn't load the private key: \(Self.describe(error))")
            }
            guard let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, message as CFData, &error) else {
                throw .authentication("Couldn't sign the JWT: \(Self.describe(error))")
            }
            return signature as Data
        }

        private static func describe(_ error: Unmanaged<CFError>?) -> String {
            error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown error"
        }
    #endif

    /// Pulls the PKCS#1 key out of a PKCS#8 `PrivateKeyInfo`:
    /// `SEQUENCE { INTEGER version, SEQUENCE algorithm, OCTET STRING privateKey }`.
    static func unwrapPKCS8(_ data: Data) throws(GitHubError) -> Data {
        var reader = DERReader(bytes: [UInt8](data))
        guard let outer = reader.read(tag: 0x30) else { throw .authentication("The private key isn't PKCS#8.") }
        var inner = DERReader(bytes: outer)
        guard inner.read(tag: 0x02) != nil,  // version
            inner.read(tag: 0x30) != nil,  // algorithm identifier
            let key = inner.read(tag: 0x04)  // private key
        else { throw .authentication("The private key isn't an RSA PKCS#8 key.") }
        return Data(key)
    }
}

/// A minimal DER reader, enough to unwrap a PKCS#8 key.
struct DERReader {
    let bytes: [UInt8]
    var offset = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    /// Reads one element with the given tag and returns its contents.
    mutating func read(tag: UInt8) -> [UInt8]? {
        guard offset < bytes.count, bytes[offset] == tag else { return nil }
        offset += 1
        guard let length = readLength(), offset + length <= bytes.count else { return nil }
        defer { offset += length }
        return Array(bytes[offset..<offset + length])
    }

    private mutating func readLength() -> Int? {
        guard offset < bytes.count else { return nil }
        let first = bytes[offset]
        offset += 1
        if first < 0x80 { return Int(first) }
        let count = Int(first & 0x7F)
        guard count > 0, count <= 4, offset + count <= bytes.count else { return nil }
        var length = 0
        for byte in bytes[offset..<offset + count] { length = (length << 8) | Int(byte) }
        offset += count
        return length
    }
}
