/// A 6-character friend challenge, e.g. `K7Q2XM`.
///
/// Layout (30 bits = 6 symbols): 5 payload symbols holding 3 bits of config version and
/// 22 bits of seed, followed by 1 check symbol.
public struct ChallengeCode: Sendable, Hashable, CustomStringConvertible {
    public static let length = 6
    static let seedBits = 22
    public static let maxSeed = UInt32(1 << seedBits) - 1
    public static let maxConfigVersion = 7

    public let configVersion: Int
    public let seed: UInt32

    public init?(configVersion: Int, seed: UInt32) {
        guard (1...Self.maxConfigVersion).contains(configVersion), seed <= Self.maxSeed else { return nil }
        self.configVersion = configVersion
        self.seed = seed
    }

    /// Accepts lowercase, hyphens/spaces, and the look-alikes O/I/L. Nil on a bad length or check digit.
    public init?(_ string: String) {
        guard let digits = CrockfordBase32.digits(from: string), digits.count == Self.length else { return nil }
        let payload = Array(digits.prefix(Self.length - 1))
        guard CrockfordBase32.checkDigit(for: payload) == digits.last else { return nil }
        let value = CrockfordBase32.value(of: payload)
        self.init(configVersion: Int(value >> UInt64(Self.seedBits)), seed: UInt32(value & UInt64(Self.maxSeed)))
    }

    public var description: String {
        let value = UInt64(configVersion) << UInt64(Self.seedBits) | UInt64(seed)
        let payload = CrockfordBase32.digits(of: value, count: Self.length - 1)
        return CrockfordBase32.string(from: payload + [CrockfordBase32.checkDigit(for: payload)])
    }

    /// The 64-bit seed actually fed to the simulation.
    public var simulationSeed: UInt64 {
        StableHash.fnv1a("CSR-challenge-v\(configVersion)-\(seed)")
    }

    public static func random(
        configVersion: Int = GameConfig.current.version,
        using generator: inout some RandomNumberGenerator
    ) -> ChallengeCode {
        let seed = UInt32.random(in: 0...maxSeed, using: &generator)
        return ChallengeCode(configVersion: configVersion, seed: seed)!
    }
}
