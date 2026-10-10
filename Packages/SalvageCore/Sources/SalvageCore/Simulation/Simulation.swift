import Foundation


/// The whole game rules engine. A value type advanced one fixed tick at a time.
///
/// The presentation layer feeds `PlayerInput`s into `step(inputs:)` and reacts to the
/// returned `GameEvent`s; it never mutates game state directly.
public struct Simulation: Sendable {
    public let config: GameConfig
    public let mode: RunMode
    public let seed: UInt64
    public let modifiers: RunModifiers
    public private(set) var state: RunState

    private var spawns: SpawnStream
    private var pendingSpawn: SpawnEvent?
    private let curve: DifficultyCurve

    public init(seed: UInt64, mode: RunMode, config: GameConfig = .current, modifiers: RunModifiers = .none) {
        let modifiers = mode.allowsUpgrades ? modifiers : .none
        self.config = config
        self.mode = mode
        self.seed = seed
        self.modifiers = modifiers
        curve = DifficultyCurve(config: config)
        state = RunState(
            combo: ComboTracker(tiers: config.comboTiers),
            bufferCapacity: config.bufferSlots + modifiers.bufferBonus,
            shieldsRemaining: modifiers.comboShields
        )
        spawns = mode == .tutorial ? .tutorial(config: config) : SpawnStream(seed: seed, config: config)
        pendingSpawn = spawns.next()
    }

    public var elapsedSeconds: Double {
        Double(state.tick) / Double(config.tickRate)
    }

    public var canRevive: Bool {
        state.isOver && mode.allowsRevive && state.revivesUsed < config.maxRevives
    }

    public var summary: RunSummary {
        RunSummary(
            seed: seed,
            configVersion: config.version,
            score: state.score,
            durationSeconds: elapsedSeconds,
            bestCombo: state.combo.best,
            standardSorted: state.sorted[.standard, default: 0],
            valuableSorted: state.sorted[.valuable, default: 0],
            hazardousSorted: state.sorted[.hazardous, default: 0],
            missorts: state.missorts,
            revivesUsed: state.revivesUsed
        )
    }

    // MARK: - Stepping

    public mutating func step(inputs: [PlayerInput] = []) -> [GameEvent] {
        guard !state.isOver else { return [] }
        var events: [GameEvent] = []
        for input in inputs {
            apply(input, into: &events)
        }
        spawnDue(into: &events)
        advanceBelt(into: &events)
        burnFuses(into: &events)
        if state.bufferOccupancy >= state.bufferCapacity {
            addOverload(config.bufferFullPerSecond / Double(config.tickRate))
        }
        state.tick += 1
        finishIfNeeded(into: &events)
        return events
    }

    /// Continues a finished Endless run: clears the board and drops overload to `reviveOverload`.
    public mutating func revive() -> [GameEvent] {
        guard canRevive else { return [] }
        state.isOver = false
        state.revivesUsed += 1
        state.overload = config.reviveOverload
        state.items.removeAll()
        return [.revived]
    }

    // MARK: - Input

    private mutating func apply(_ input: PlayerInput, into events: inout [GameEvent]) {
        switch input {
        case .grab(let id):
            if let index = index(of: id) { state.items[index].isHeld = true }

        case .release(let id):
            if let index = index(of: id) { state.items[index].isHeld = false }

        case .drop(let id, let bin):
            guard let index = index(of: id) else { return }
            let item = state.items[index]
            if bin.accepts == item.kind {
                state.items.remove(at: index)
                registerSort(item, bin: bin, into: &events)
            } else if mode == .tutorial {
                state.items[index].isHeld = false
                events.append(.rejected(itemID: id, bin: bin))
            } else if state.shieldsRemaining > 0 {
                state.items.remove(at: index)
                state.shieldsRemaining -= 1
                events.append(.shieldUsed(itemID: id, bin: bin))
            } else {
                state.items.remove(at: index)
                state.missorts += 1
                addOverload(config.missortPenalty)
                events.append(.missorted(itemID: id, bin: bin))
                breakCombo(into: &events)
            }
        }
    }

    private mutating func registerSort(_ item: Item, bin: BinID, into events: inout [GameEvent]) {
        let (multiplier, tierUp) = state.combo.registerSuccess()
        let points = ScoreEngine.points(for: item.kind, multiplier: multiplier, config: config)
        state.score += points
        state.sorted[item.kind, default: 0] += 1
        addOverload(-config.correctSortRelief)
        events.append(.sorted(itemID: item.id, bin: bin, points: points, combo: state.combo.count, multiplier: multiplier))
        if tierUp {
            events.append(.comboTierUp(multiplier: multiplier))
        }
    }

    // MARK: - Tick phases

    private mutating func spawnDue(into events: inout [GameEvent]) {
        while let spawn = pendingSpawn, spawn.tick <= state.tick {
            let fuse = spawn.kind == .hazardous
                ? config.ticks(config.hazardFuseSeconds * modifiers.fuseMultiplier)
                : nil
            let item = Item(id: spawn.id, kind: spawn.kind, lane: spawn.lane, location: .belt(progress: 0), fuseTicks: fuse)
            state.items.append(item)
            events.append(.spawned(item))
            pendingSpawn = spawns.next()
        }
    }

    private mutating func advanceBelt(into events: inout [GameEvent]) {
        let delta = 1 / (curve.travelSeconds(at: elapsedSeconds) * Double(config.tickRate))
        var index = 0
        while index < state.items.count {
            let item = state.items[index]
            guard case .belt(let progress) = item.location, !item.isHeld else {
                index += 1
                continue
            }
            var next = progress + delta
            if mode == .tutorial {
                next = min(next, config.tutorialHoldProgress)
            }
            if next < 1 {
                state.items[index].location = .belt(progress: next)
            } else if let slot = freeBufferSlot() {
                state.items[index].location = .buffer(slot: slot)
                events.append(.enteredBuffer(itemID: item.id, slot: slot))
            } else {
                state.items.remove(at: index)
                addOverload(config.lostItemPenalty)
                events.append(.lost(itemID: item.id))
                breakCombo(into: &events)
                continue
            }
            index += 1
        }
    }

    private mutating func burnFuses(into events: inout [GameEvent]) {
        guard mode.usesOverload else { return }
        var index = 0
        while index < state.items.count {
            guard let fuse = state.items[index].fuseTicks else {
                index += 1
                continue
            }
            if fuse > 1 {
                state.items[index].fuseTicks = fuse - 1
                index += 1
            } else {
                let item = state.items.remove(at: index)
                addOverload(config.hazardExpiredPenalty)
                events.append(.hazardExpired(itemID: item.id))
                breakCombo(into: &events)
            }
        }
    }

    private mutating func finishIfNeeded(into events: inout [GameEvent]) {
        let failed = mode.usesOverload && state.overload >= config.maxOverload
        let tutorialDone = mode == .tutorial && pendingSpawn == nil && state.items.isEmpty
        guard failed || tutorialDone else { return }
        state.isOver = true
        events.append(.runEnded(summary))
    }

    // MARK: - Helpers

    private func index(of id: Int) -> Int? {
        state.items.firstIndex { $0.id == id }
    }

    private func freeBufferSlot() -> Int? {
        let taken = Set(state.items.compactMap(\.bufferSlot))
        return (0..<state.bufferCapacity).first { !taken.contains($0) }
    }

    private mutating func addOverload(_ amount: Double) {
        guard mode.usesOverload else { return }
        state.overload = min(max(state.overload + amount, 0), config.maxOverload)
    }

    private mutating func breakCombo(into events: inout [GameEvent]) {
        let previous = state.combo.reset()
        if previous > 0 {
            events.append(.comboBroken(previous: previous))
        }
    }
}

// MARK: - Mode factories

extension Simulation {
    public static func endless(seed: UInt64, modifiers: RunModifiers = .none) -> Simulation {
        Simulation(seed: seed, mode: .endless, modifiers: modifiers)
    }

    public static func daily(for date: Date) -> Simulation {
        Simulation(seed: DailySeed.seed(for: date), mode: .daily)
    }

    /// Nil when the code was made by a newer app version whose config this build doesn't have.
    public static func challenge(_ code: ChallengeCode) -> Simulation? {
        guard let config = GameConfig.version(code.configVersion) else { return nil }
        return Simulation(seed: code.simulationSeed, mode: .challenge(code), config: config)
    }

    public static func tutorial() -> Simulation {
        Simulation(seed: 0, mode: .tutorial)
    }
}
