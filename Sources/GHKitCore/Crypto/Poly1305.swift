/// Poly1305, the one-time authenticator in NaCl's `crypto_secretbox` (RFC 8439, section 2.5).
///
/// This is the 32-bit "donna" form: the 130-bit accumulator is five 26-bit limbs, and the final
/// reduction picks between `h` and `h - p` with masks, so no branch depends on the key or message.
enum Poly1305 {
    static let limb: UInt32 = 0x3ff_ffff

    /// The 16-byte tag for `message` under a 32-byte one-time key.
    static func tag(_ message: [UInt8], key: [UInt8]) -> [UInt8] {
        // r, clamped as the spec requires, in 26-bit limbs.
        let r0 = loadLittleEndian(key, at: 0) & 0x3ff_ffff
        let r1 = (loadLittleEndian(key, at: 3) >> 2) & 0x3ff_ff03
        let r2 = (loadLittleEndian(key, at: 6) >> 4) & 0x3ff_c0ff
        let r3 = (loadLittleEndian(key, at: 9) >> 6) & 0x3f0_3fff
        let r4 = (loadLittleEndian(key, at: 12) >> 8) & 0x00f_ffff
        let s1 = r1 * 5
        let s2 = r2 * 5
        let s3 = r3 * 5
        let s4 = r4 * 5

        var h0: UInt32 = 0
        var h1: UInt32 = 0
        var h2: UInt32 = 0
        var h3: UInt32 = 0
        var h4: UInt32 = 0

        var offset = 0
        while offset < message.count {
            // A full block gets a 1 bit above its 128 bits; a short final block gets a 0x01 byte after its last byte.
            var block = [UInt8](repeating: 0, count: 16)
            let count = min(16, message.count - offset)
            block[0..<count] = message[offset..<offset + count]
            let high: UInt32
            if count == 16 {
                high = 1 << 24
            } else {
                block[count] = 1
                high = 0
            }
            offset += count

            h0 &+= loadLittleEndian(block, at: 0) & limb
            h1 &+= (loadLittleEndian(block, at: 3) >> 2) & limb
            h2 &+= (loadLittleEndian(block, at: 6) >> 4) & limb
            h3 &+= (loadLittleEndian(block, at: 9) >> 6) & limb
            h4 &+= (loadLittleEndian(block, at: 12) >> 8) | high

            // h *= r, modulo 2^130 - 5. Limbs above the top wrap around multiplied by 5.
            let d0 = mul(h0, r0) + mul(h1, s4) + mul(h2, s3) + mul(h3, s2) + mul(h4, s1)
            var d1 = mul(h0, r1) + mul(h1, r0) + mul(h2, s4) + mul(h3, s3) + mul(h4, s2)
            var d2 = mul(h0, r2) + mul(h1, r1) + mul(h2, r0) + mul(h3, s4) + mul(h4, s3)
            var d3 = mul(h0, r3) + mul(h1, r2) + mul(h2, r1) + mul(h3, r0) + mul(h4, s4)
            var d4 = mul(h0, r4) + mul(h1, r3) + mul(h2, r2) + mul(h3, r1) + mul(h4, r0)

            var carry = d0 >> 26
            h0 = UInt32(truncatingIfNeeded: d0) & limb
            d1 += carry
            carry = d1 >> 26
            h1 = UInt32(truncatingIfNeeded: d1) & limb
            d2 += carry
            carry = d2 >> 26
            h2 = UInt32(truncatingIfNeeded: d2) & limb
            d3 += carry
            carry = d3 >> 26
            h3 = UInt32(truncatingIfNeeded: d3) & limb
            d4 += carry
            carry = d4 >> 26
            h4 = UInt32(truncatingIfNeeded: d4) & limb
            h0 &+= UInt32(truncatingIfNeeded: carry) &* 5
            h1 &+= h0 >> 26
            h0 &= limb
        }

        // Carry fully.
        var c = h1 >> 26
        h1 &= limb
        h2 &+= c
        c = h2 >> 26
        h2 &= limb
        h3 &+= c
        c = h3 >> 26
        h3 &= limb
        h4 &+= c
        c = h4 >> 26
        h4 &= limb
        h0 &+= c &* 5
        c = h0 >> 26
        h0 &= limb
        h1 &+= c

        // g = h + 5 - 2^130. Keep h if that's negative, otherwise g.
        var g0 = h0 &+ 5
        c = g0 >> 26
        g0 &= limb
        var g1 = h1 &+ c
        c = g1 >> 26
        g1 &= limb
        var g2 = h2 &+ c
        c = g2 >> 26
        g2 &= limb
        var g3 = h3 &+ c
        c = g3 >> 26
        g3 &= limb
        var g4 = h4 &+ c &- (1 << 26)

        var mask = (g4 >> 31) &- 1
        g0 &= mask
        g1 &= mask
        g2 &= mask
        g3 &= mask
        g4 &= mask
        mask = ~mask
        h0 = (h0 & mask) | g0
        h1 = (h1 & mask) | g1
        h2 = (h2 & mask) | g2
        h3 = (h3 & mask) | g3
        h4 = (h4 & mask) | g4

        // Back to four 32-bit words, then add s modulo 2^128.
        let words: [UInt32] = [h0 | h1 << 26, h1 >> 6 | h2 << 20, h2 >> 12 | h3 << 14, h3 >> 18 | h4 << 8]
        var sum: UInt64 = 0
        var tag: [UInt32] = []
        for (i, word) in words.enumerated() {
            sum = UInt64(word) + UInt64(loadLittleEndian(key, at: 16 + 4 * i)) + (sum >> 32)
            tag.append(UInt32(truncatingIfNeeded: sum))
        }
        return Salsa20.bytes(tag)
    }

    static func mul(_ a: UInt32, _ b: UInt32) -> UInt64 {
        UInt64(a) * UInt64(b)
    }
}
