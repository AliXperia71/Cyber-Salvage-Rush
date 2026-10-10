public struct SpawnEvent: Sendable, Equatable {
    public let tick: Int
    public let id: Int
    public let kind: ItemKind
    public let lane: Int
}

/// Produces the item sequence for a run.
///
/// The sequence depends only on `(seed, config)`, never on player actions, so every
/// player of a daily or challenge seed sees the same belt.
public struct SpawnStream: Sendable {
    private enum Source: Sendable {
        case seeded(SeededGenerator, DifficultyCurve)
        case scripted([SpawnEvent])
    }

    private var source: Source
    private var nextID = 0
    private var nextTick: Int
    private let config: GameConfig

    public init(seed: UInt64, config: GameConfig) {
        self.config = config
        source = .seeded(SeededGenerator(seed: seed), DifficultyCurve(config: config))
        nextTick = config.ticks(config.firstSpawnSeconds)
    }

    /// Fixed sequence, used by the tutorial. Events must be in ascending tick order.
    public init(script: [SpawnEvent], config: GameConfig) {
        self.config = config
        source = .scripted(script)
        nextTick = 0
    }

    /// Tutorial: one of each kind, a couple of seconds apart.
    public static func tutorial(config: GameConfig) -> SpawnStream {
        let kinds: [ItemKind] = [.standard, .valuable, .hazardous]
        let script = kinds.enumerated().map { index, kind in
            SpawnEvent(tick: config.ticks(0.5 + Double(index) * 2.0), id: index, kind: kind, lane: index % config.laneCount)
        }
        return SpawnStream(script: script, config: config)
    }

    /// The next spawn, or nil when a scripted sequence is exhausted.
    public mutating func next() -> SpawnEvent? {
        switch source {
        case .scripted(var script):
            guard !script.isEmpty else { return nil }
            let event = script.removeFirst()
            source = .scripted(script)
            return event

        case .seeded(var rng, let curve):
            let seconds = Double(nextTick) / Double(config.tickRate)
            let hazard = curve.hazardChance(at: seconds)
            let roll = rng.unitDouble()
            let kind: ItemKind =
                if roll < hazard { .hazardous }
                else if roll < hazard + config.valuableChance { .valuable }
                else { .standard }
            let lane = rng.int(below: config.laneCount)
            let event = SpawnEvent(tick: nextTick, id: nextID, kind: kind, lane: lane)

            let jitter = 1 + config.spawnJitter * (2 * rng.unitDouble() - 1)
            nextTick += max(1, config.ticks(curve.spawnInterval(at: seconds) * jitter))
            nextID += 1
            source = .seeded(rng, curve)
            return event
        }
    }
}
