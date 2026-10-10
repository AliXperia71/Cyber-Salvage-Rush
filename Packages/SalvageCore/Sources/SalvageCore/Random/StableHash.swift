/// FNV-1a 64-bit. Stable across launches, unlike Swift's `Hasher`, which is
/// randomly seeded per process and must never be used to derive game seeds.
public enum StableHash {
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
