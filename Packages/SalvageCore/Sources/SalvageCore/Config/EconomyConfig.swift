/// Progression tuning. Separate from `GameConfig` because economy changes don't
/// affect run determinism and need no versioning.
public struct EconomyConfig: Sendable, Equatable {
    public var scorePerCredit: Int
    public var firstRunOfDayBonus: Int
    /// Cost to reach level N is `costs[N - 1]`; the array length is the max level.
    public var upgradeCosts: [Upgrade: [Int]]
    public var bufferBonusByLevel: [Int]
    public var fuseMultiplierByLevel: [Double]
    public var comboShieldsByLevel: [Int]
    public var catalog: [Cosmetic]

    public static let standard = EconomyConfig(
        scorePerCredit: 50,
        firstRunOfDayBonus: 20,
        upgradeCosts: [
            .bufferExpansion: [400, 1_200],
            .fuseDampener: [250, 600, 1_200],
            .comboShield: [500, 1_500],
        ],
        bufferBonusByLevel: [0, 1, 2],
        fuseMultiplierByLevel: [1.0, 1.05, 1.10, 1.15],
        comboShieldsByLevel: [0, 1, 2],
        catalog: [
            Cosmetic(id: "theme.foundry", name: "Foundry", kind: .theme, price: 0),
            Cosmetic(id: "theme.neonTide", name: "Neon Tide", kind: .theme, price: 150),
            Cosmetic(id: "theme.rustBelt", name: "Rust Belt", kind: .theme, price: 350),
            Cosmetic(id: "theme.voidChrome", name: "Void Chrome", kind: .theme, price: 700),
            Cosmetic(id: "drone.spark", name: "Spark", kind: .drone, price: 0),
            Cosmetic(id: "drone.magpie", name: "Magpie", kind: .drone, price: 200),
            Cosmetic(id: "drone.warden", name: "Warden", kind: .drone, price: 450),
            Cosmetic(id: "drone.halo", name: "Halo", kind: .drone, price: 900),
        ]
    )
}
