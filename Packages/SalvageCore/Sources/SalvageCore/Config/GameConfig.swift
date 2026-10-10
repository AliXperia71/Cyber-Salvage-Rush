/// Every gameplay tuning value lives here.
///
/// Shipped versions are frozen: daily seeds and challenge codes replay against the
/// config version they were created with, so a balance change means adding `v2`
/// and pointing `current` at it, never editing `v1` after release.
public struct GameConfig: Sendable, Equatable {
    public struct ComboTier: Sendable, Equatable {
        public var threshold: Int
        public var multiplier: Int
    }

    public var version: Int

    // MARK: Timing
    public var tickRate: Int

    // MARK: Board
    public var laneCount: Int
    public var bufferSlots: Int

    // MARK: Difficulty
    /// Seconds until the main ramp reaches its end values.
    public var rampSeconds: Double
    /// Seconds an item takes to cross the belt.
    public var travelSecondsStart: Double
    public var travelSecondsEnd: Double
    public var spawnIntervalStart: Double
    public var spawnIntervalEnd: Double
    /// After the ramp, the spawn interval keeps shrinking by this fraction per second...
    public var overtimeTightenPerSecond: Double
    /// ...down to this fraction of `spawnIntervalEnd`.
    public var overtimeFloor: Double
    /// Spawn interval is randomized by ±this fraction.
    public var spawnJitter: Double
    public var firstSpawnSeconds: Double
    public var hazardChanceStart: Double
    public var hazardChanceEnd: Double
    public var valuableChance: Double
    public var hazardFuseSeconds: Double

    // MARK: Scoring
    public var standardPoints: Int
    public var valuablePoints: Int
    public var hazardousPoints: Int
    /// Ascending by threshold; the first tier must have threshold 0.
    public var comboTiers: [ComboTier]

    // MARK: Overload (0...maxOverload; run ends at max)
    public var maxOverload: Double
    public var missortPenalty: Double
    public var lostItemPenalty: Double
    public var hazardExpiredPenalty: Double
    public var bufferFullPerSecond: Double
    public var correctSortRelief: Double
    public var reviveOverload: Double
    public var maxRevives: Int

    // MARK: Tutorial
    /// Tutorial items stop here and wait for the player.
    public var tutorialHoldProgress: Double

    public func points(for kind: ItemKind) -> Int {
        switch kind {
        case .standard: standardPoints
        case .valuable: valuablePoints
        case .hazardous: hazardousPoints
        }
    }

    public func ticks(_ seconds: Double) -> Int {
        Int((seconds * Double(tickRate)).rounded())
    }
}

extension GameConfig {
    public static let v1 = GameConfig(
        version: 1,
        tickRate: 60,
        laneCount: 2,
        bufferSlots: 4,
        rampSeconds: 45,
        travelSecondsStart: 7.0,
        travelSecondsEnd: 3.6,
        spawnIntervalStart: 1.3,
        spawnIntervalEnd: 0.42,
        overtimeTightenPerSecond: 0.01,
        overtimeFloor: 0.5,
        spawnJitter: 0.2,
        firstSpawnSeconds: 0.6,
        hazardChanceStart: 0.10,
        hazardChanceEnd: 0.28,
        valuableChance: 0.15,
        hazardFuseSeconds: 9,
        standardPoints: 10,
        valuablePoints: 30,
        hazardousPoints: 20,
        comboTiers: [
            ComboTier(threshold: 0, multiplier: 1),
            ComboTier(threshold: 5, multiplier: 2),
            ComboTier(threshold: 12, multiplier: 3),
            ComboTier(threshold: 25, multiplier: 4),
        ],
        maxOverload: 100,
        missortPenalty: 12,
        lostItemPenalty: 8,
        hazardExpiredPenalty: 20,
        bufferFullPerSecond: 4,
        correctSortRelief: 1.5,
        reviveOverload: 50,
        maxRevives: 1,
        tutorialHoldProgress: 0.55
    )

    /// The version new runs and new challenge codes use.
    public static let current = v1

    public static func version(_ number: Int) -> GameConfig? {
        switch number {
        case 1: v1
        default: nil
        }
    }
}
