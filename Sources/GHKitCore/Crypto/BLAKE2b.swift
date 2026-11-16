/// Unkeyed BLAKE2b (RFC 7693), which a sealed box uses to derive its nonce from the two public keys.
enum BLAKE2b {
    static let iv: [UInt64] = [
        0x6a09_e667_f3bc_c908, 0xbb67_ae85_84ca_a73b, 0x3c6e_f372_fe94_f82b, 0xa54f_f53a_5f1d_36f1,
        0x510e_527f_ade6_82d1, 0x9b05_688c_2b3e_6c1f, 0x1f83_d9ab_fb41_bd6b, 0x5be0_cd19_137e_2179,
    ]

    /// The message word order for each round. Rounds 10 and 11 reuse rows 0 and 1.
    static let sigma: [[Int]] = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    ]

    /// The first `outputLength` bytes (1 to 64) of the hash of `message`.
    static func hash(_ message: [UInt8], outputLength: Int) -> [UInt8] {
        precondition((1...64).contains(outputLength), "BLAKE2b produces 1 to 64 bytes.")
        var h = iv
        h[0] ^= 0x0101_0000 ^ UInt64(outputLength)

        var offset = 0
        // Every block but the last is compressed as it is; the last is padded with zeros and flagged.
        while message.count - offset > 128 {
            compress(&h, block: Array(message[offset..<offset + 128]), counter: UInt64(offset + 128), isLast: false)
            offset += 128
        }
        var last = Array(message[offset...])
        last += [UInt8](repeating: 0, count: 128 - last.count)
        compress(&h, block: last, counter: UInt64(message.count), isLast: true)

        let bytes = h.flatMap { word in (0..<8).map { UInt8(truncatingIfNeeded: word >> (8 * UInt64($0))) } }
        return Array(bytes.prefix(outputLength))
    }

    static func compress(_ h: inout [UInt64], block: [UInt8], counter: UInt64, isLast: Bool) {
        let m = stride(from: 0, to: 128, by: 8).map { start in
            (0..<8).reduce(UInt64(0)) { word, i in word | UInt64(block[start + i]) << (8 * UInt64(i)) }
        }
        var v = h + iv
        v[12] ^= counter
        if isLast { v[14] = ~v[14] }

        func mix(_ a: Int, _ b: Int, _ c: Int, _ d: Int, _ x: UInt64, _ y: UInt64) {
            v[a] = v[a] &+ v[b] &+ x
            v[d] = rotate(v[d] ^ v[a], 32)
            v[c] = v[c] &+ v[d]
            v[b] = rotate(v[b] ^ v[c], 24)
            v[a] = v[a] &+ v[b] &+ y
            v[d] = rotate(v[d] ^ v[a], 16)
            v[c] = v[c] &+ v[d]
            v[b] = rotate(v[b] ^ v[c], 63)
        }
        for round in 0..<12 {
            let s = sigma[round % 10]
            mix(0, 4, 8, 12, m[s[0]], m[s[1]])
            mix(1, 5, 9, 13, m[s[2]], m[s[3]])
            mix(2, 6, 10, 14, m[s[4]], m[s[5]])
            mix(3, 7, 11, 15, m[s[6]], m[s[7]])
            mix(0, 5, 10, 15, m[s[8]], m[s[9]])
            mix(1, 6, 11, 12, m[s[10]], m[s[11]])
            mix(2, 7, 8, 13, m[s[12]], m[s[13]])
            mix(3, 4, 9, 14, m[s[14]], m[s[15]])
        }
        for i in 0..<8 {
            h[i] ^= v[i] ^ v[i + 8]
        }
    }

    /// Rotate right.
    static func rotate(_ value: UInt64, _ count: UInt64) -> UInt64 {
        (value >> count) | (value << (64 - count))
    }
}
