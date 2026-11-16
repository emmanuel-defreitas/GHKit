/// Salsa20 and the HSalsa20 and XSalsa20 constructions that NaCl's `crypto_box` builds on.
///
/// Only add, rotate, and XOR on `UInt32`, so the time it takes doesn't depend on the key.
enum Salsa20 {
    /// "expand 32-byte k"
    static let sigma: [UInt32] = [0x6170_7865, 0x3320_646e, 0x7962_2d32, 0x6b20_6574]

    /// The 16 input words for a 32-byte key and 16 bytes of nonce or nonce and counter.
    static func state(key: [UInt8], input: [UInt8]) -> [UInt32] {
        let k = words(key)
        let n = words(input)
        return [
            sigma[0], k[0], k[1], k[2], k[3], sigma[1], n[0], n[1], n[2], n[3], sigma[2], k[4], k[5], k[6], k[7], sigma[3],
        ]
    }

    /// The 20 rounds: 10 column rounds, each followed by a row round.
    static func rounds(_ x: inout [UInt32]) {
        func quarter(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
            x[b] ^= rotate(x[a] &+ x[d], 7)
            x[c] ^= rotate(x[b] &+ x[a], 9)
            x[d] ^= rotate(x[c] &+ x[b], 13)
            x[a] ^= rotate(x[d] &+ x[c], 18)
        }
        for _ in 0..<10 {
            quarter(0, 4, 8, 12)
            quarter(5, 9, 13, 1)
            quarter(10, 14, 2, 6)
            quarter(15, 3, 7, 11)
            quarter(0, 1, 2, 3)
            quarter(5, 6, 7, 4)
            quarter(10, 11, 8, 9)
            quarter(15, 12, 13, 14)
        }
    }

    /// HSalsa20: a 32-byte subkey from a 32-byte key and a 16-byte nonce.
    static func hsalsa20(key: [UInt8], nonce: [UInt8]) -> [UInt8] {
        var x = state(key: key, input: nonce)
        rounds(&x)
        return bytes([x[0], x[5], x[10], x[15], x[6], x[7], x[8], x[9]])
    }

    /// One 64-byte block of Salsa20 keystream for an 8-byte nonce.
    static func block(key: [UInt8], nonce: [UInt8], counter: UInt64) -> [UInt8] {
        let input = nonce + (0..<8).map { UInt8(truncatingIfNeeded: counter >> (8 * UInt64($0))) }
        let initial = state(key: key, input: input)
        var x = initial
        rounds(&x)
        return bytes(zip(x, initial).map { $0 &+ $1 })
    }

    /// `data` XORed with the XSalsa20 keystream for a 32-byte key and a 24-byte nonce.
    static func xsalsa20XOR(_ data: [UInt8], key: [UInt8], nonce: [UInt8]) -> [UInt8] {
        let subkey = hsalsa20(key: key, nonce: Array(nonce[0..<16]))
        let streamNonce = Array(nonce[16..<24])
        var output = data
        var counter: UInt64 = 0
        var offset = 0
        while offset < output.count {
            let stream = block(key: subkey, nonce: streamNonce, counter: counter)
            for i in 0..<min(64, output.count - offset) {
                output[offset + i] ^= stream[i]
            }
            offset += 64
            counter += 1
        }
        return output
    }

    static func rotate(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value << count) | (value >> (32 - count))
    }

    /// Little-endian words from bytes whose count is a multiple of 4.
    static func words(_ bytes: [UInt8]) -> [UInt32] {
        stride(from: 0, to: bytes.count, by: 4).map { loadLittleEndian(bytes, at: $0) }
    }

    static func bytes(_ words: [UInt32]) -> [UInt8] {
        words.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> (8 * UInt32($0))) } }
    }
}

/// The little-endian `UInt32` at `offset`.
func loadLittleEndian(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
}
