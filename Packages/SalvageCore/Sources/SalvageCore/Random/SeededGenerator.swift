/// SplitMix64. Deterministic across devices, OS versions, and Swift versions.
///
/// Use `unitDouble()` / `int(below:)` instead of the stdlib `random(in:using:)`
/// helpers: their algorithms are not guaranteed stable across Swift releases,
/// which would silently change daily and challenge runs.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unitDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// Uniform in 0..<bound. Modulo bias is negligible for the tiny bounds used in gameplay.
    public mutating func int(below bound: Int) -> Int {
        precondition(bound > 0)
        return Int(next() % UInt64(bound))
    }
}
