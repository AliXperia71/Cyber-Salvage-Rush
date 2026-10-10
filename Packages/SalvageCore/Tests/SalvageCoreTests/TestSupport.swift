@testable import SalvageCore

extension Simulation {
    /// Steps until a condition holds or `maxTicks` elapse. Returns every event produced.
    @discardableResult
    mutating func run(maxTicks: Int, until stop: (Simulation) -> Bool = { _ in false }) -> [GameEvent] {
        var events: [GameEvent] = []
        for _ in 0..<maxTicks {
            if stop(self) { break }
            events += step()
        }
        return events
    }

    /// Steps until at least one item is on the board and returns the first one.
    mutating func firstItem(where predicate: (Item) -> Bool = { _ in true }) -> Item {
        run(maxTicks: 10_000) { sim in sim.state.items.contains(where: predicate) }
        return state.items.first(where: predicate)!
    }
}

extension GameConfig {
    func with(_ change: (inout GameConfig) -> Void) -> GameConfig {
        var copy = self
        change(&copy)
        return copy
    }
}

/// A simulated player: one drag at a time, a human-ish reaction delay, and occasional mistakes.
struct BalanceBot {
    var reactionSeconds = 0.35
    var dragSeconds = 0.50
    var errorRate = 0.05
    var rng: SeededGenerator

    private var busyUntilTick = 0
    private var seenAt: [Int: Int] = [:]

    init(seed: UInt64) {
        rng = SeededGenerator(seed: seed ^ 0xB07)
    }

    mutating func inputs(for sim: Simulation) -> [PlayerInput] {
        let tick = sim.state.tick
        for item in sim.state.items where seenAt[item.id] == nil {
            seenAt[item.id] = tick
        }
        guard tick >= busyUntilTick else { return [] }

        let reaction = sim.config.ticks(reactionSeconds)
        let candidates = sim.state.items.filter { tick - seenAt[$0.id]! >= reaction }
        guard let target = candidates.min(by: { urgency($0, sim) < urgency($1, sim) }) else { return [] }

        busyUntilTick = tick + sim.config.ticks(dragSeconds)
        var bin = BinID.matching(target.kind)
        if rng.unitDouble() < errorRate {
            bin = BinID.allCases.first { $0 != bin }!
        }
        return [.drop(itemID: target.id, bin: bin)]
    }

    /// Lower is more urgent: hazards about to blow, then buffered items, then items nearest the belt end.
    private func urgency(_ item: Item, _ sim: Simulation) -> Double {
        if let fuse = item.fuseTicks, fuse < sim.config.ticks(3) { return -10 + Double(fuse) / 1_000 }
        switch item.location {
        case .buffer: return -5
        case .belt(let progress): return 1 - progress
        }
    }

    static func play(seed: UInt64, config: GameConfig = .current, maxSeconds: Double = 600) -> RunSummary {
        var sim = Simulation(seed: seed, mode: .endless, config: config)
        var bot = BalanceBot(seed: seed)
        let maxTicks = sim.config.ticks(maxSeconds)
        while !sim.state.isOver, sim.state.tick < maxTicks {
            _ = sim.step(inputs: bot.inputs(for: sim))
        }
        return sim.summary
    }
}
