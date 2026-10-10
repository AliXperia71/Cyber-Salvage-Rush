import Testing
@testable import SalvageCore

struct SimulationTests {
    @Test func correctDropScoresAndRelievesOverload() {
        var sim = Simulation.endless(seed: 1)
        let item = sim.firstItem()
        let events = sim.step(inputs: [.drop(itemID: item.id, bin: .matching(item.kind))])
        #expect(sim.state.score == GameConfig.v1.points(for: item.kind))
        #expect(sim.state.item(id: item.id) == nil)
        #expect(sim.state.overload == 0, "relief never goes below zero")
        #expect(events.contains { if case .sorted(item.id, _, _, 1, 1) = $0 { true } else { false } })
    }

    @Test func missortAddsPenaltyAndBreaksCombo() {
        var sim = Simulation.endless(seed: 1)
        for _ in 0..<3 {
            let item = sim.firstItem()
            _ = sim.step(inputs: [.drop(itemID: item.id, bin: .matching(item.kind))])
        }
        #expect(sim.state.combo.count == 3)

        let item = sim.firstItem()
        let wrong = BinID.allCases.first { $0 != .matching(item.kind) }!
        let events = sim.step(inputs: [.drop(itemID: item.id, bin: wrong)])
        #expect(sim.state.overload == GameConfig.v1.missortPenalty)
        #expect(sim.state.combo.count == 0)
        #expect(sim.state.missorts == 1)
        #expect(events.contains(.comboBroken(previous: 3)))
    }

    @Test func comboShieldAbsorbsOneMissort() {
        var sim = Simulation.endless(seed: 1, modifiers: RunModifiers(comboShields: 1))
        for expectedOverload in [0, GameConfig.v1.missortPenalty] {
            let item = sim.firstItem()
            let wrong = BinID.allCases.first { $0 != .matching(item.kind) }!
            _ = sim.step(inputs: [.drop(itemID: item.id, bin: wrong)])
            #expect(sim.state.overload == expectedOverload)
        }
    }

    @Test func heldItemsDoNotMove() {
        var sim = Simulation.endless(seed: 3)
        let item = sim.firstItem()
        _ = sim.step(inputs: [.grab(itemID: item.id)])
        let held = sim.state.item(id: item.id)!.location
        sim.run(maxTicks: 60)
        #expect(sim.state.item(id: item.id)?.location == held)

        _ = sim.step(inputs: [.release(itemID: item.id)])
        #expect(sim.state.item(id: item.id)?.location != held)
    }

    @Test func itemsFillBufferThenGetLost() {
        let config = GameConfig.v1.with { $0.bufferSlots = 2; $0.hazardChanceStart = 0; $0.hazardChanceEnd = 0 }
        var sim = Simulation(seed: 8, mode: .endless, config: config)
        let events = sim.run(maxTicks: 60 * 20) { $0.state.isOver }
        let entered = events.compactMap { if case .enteredBuffer(_, let slot) = $0 { slot } else { nil } }
        #expect(entered == [0, 1])
        #expect(events.contains { if case .lost = $0 { true } else { false } })
    }

    @Test func fullBufferAccruesOverloadPerSecond() {
        let config = GameConfig.v1.with { $0.bufferSlots = 1; $0.lostItemPenalty = 0; $0.hazardChanceStart = 0; $0.hazardChanceEnd = 0 }
        var sim = Simulation(seed: 8, mode: .endless, config: config)
        sim.run(maxTicks: 60 * 30) { $0.state.bufferOccupancy == 1 }
        let before = sim.state.overload
        sim.run(maxTicks: 60)
        #expect(abs(sim.state.overload - before - config.bufferFullPerSecond) < 0.01)
    }

    @Test func expiredHazardSpikesOverload() {
        let config = GameConfig.v1.with { $0.hazardChanceStart = 1; $0.hazardChanceEnd = 1 }
        var sim = Simulation(seed: 2, mode: .endless, config: config)
        let first = sim.firstItem()
        var events: [GameEvent] = []
        for _ in 0..<config.ticks(config.hazardFuseSeconds) {
            events += sim.step(inputs: [.grab(itemID: first.id)])
        }
        #expect(events.contains(.hazardExpired(itemID: first.id)))
        #expect(sim.state.overload >= config.hazardExpiredPenalty)
    }

    @Test func runEndsExactlyOnceAtMaxOverload() {
        var sim = Simulation.endless(seed: 4)
        var ended = 0
        for _ in 0..<(60 * 600) {
            for event in sim.step() {
                if case .runEnded = event { ended += 1 }
            }
        }
        #expect(sim.state.isOver)
        #expect(ended == 1)
        #expect(sim.state.overload == GameConfig.v1.maxOverload)
        #expect(sim.step().isEmpty)
    }

    @Test func reviveOnlyOnceAndOnlyInEndless() {
        var sim = Simulation.endless(seed: 4)
        sim.run(maxTicks: 60 * 600) { $0.state.isOver }
        #expect(sim.revive() == [.revived])
        #expect(sim.state.overload == GameConfig.v1.reviveOverload)
        #expect(sim.state.items.isEmpty)
        sim.run(maxTicks: 60 * 600) { $0.state.isOver }
        #expect(sim.revive().isEmpty)

        var daily = Simulation(seed: 4, mode: .daily)
        daily.run(maxTicks: 60 * 600) { $0.state.isOver }
        #expect(daily.revive().isEmpty)
    }

    @Test func upgradesIgnoredOutsideEndless() {
        let mods = RunModifiers(bufferBonus: 2, fuseMultiplier: 2, comboShields: 2)
        let daily = Simulation(seed: 1, mode: .daily, modifiers: mods)
        #expect(daily.modifiers == .none)
        #expect(daily.state.bufferCapacity == GameConfig.v1.bufferSlots)
        let endless = Simulation(seed: 1, mode: .endless, modifiers: mods)
        #expect(endless.state.bufferCapacity == GameConfig.v1.bufferSlots + 2)
    }

    @Test func tutorialWaitsRejectsAndCompletes() {
        var sim = Simulation.tutorial()
        sim.run(maxTicks: 60 * 30)
        #expect(!sim.state.isOver, "tutorial never fails or advances without the player")
        #expect(sim.state.items.count == 3)
        let config = GameConfig.v1
        #expect(sim.state.items.map(\.location) == [
            .belt(progress: config.tutorialHoldProgress),
            .belt(progress: config.tutorialHoldProgress),
            .belt(progress: config.tutorialHoldProgress - config.tutorialQueueSpacing),
        ], "same-lane items queue instead of overlapping")
        #expect(sim.state.overload == 0)

        let first = sim.state.items[0]
        let wrong = BinID.allCases.first { $0 != .matching(first.kind) }!
        #expect(sim.step(inputs: [.drop(itemID: first.id, bin: wrong)]).contains(.rejected(itemID: first.id, bin: wrong)))
        #expect(sim.state.item(id: first.id) != nil)

        // Sorting the head of a lane lets the queued item move up.
        _ = sim.step(inputs: [.drop(itemID: first.id, bin: .matching(first.kind))])
        sim.run(maxTicks: 60 * 3)
        #expect(sim.state.items.allSatisfy { $0.location == .belt(progress: config.tutorialHoldProgress) })

        let drops = sim.state.items.map { PlayerInput.drop(itemID: $0.id, bin: .matching($0.kind)) }
        let events = sim.step(inputs: drops)
        #expect(sim.state.isOver)
        #expect(events.contains { if case .runEnded = $0 { true } else { false } })
    }

    /// Spec: tutorial under 20 s. A new player who drags each item ~0.8 s after it stops should finish well inside that.
    @Test func tutorialPacingFitsBudget() {
        var sim = Simulation.tutorial()
        var restingSince: [Int: Int] = [:]
        var previous: [Int: Item.Location] = [:]
        while !sim.state.isOver, sim.elapsedSeconds < 30 {
            var inputs: [PlayerInput] = []
            for item in sim.state.items {
                if previous[item.id] == item.location {
                    restingSince[item.id, default: sim.state.tick] += 0
                } else {
                    restingSince[item.id] = nil
                }
                previous[item.id] = item.location
                if let since = restingSince[item.id], sim.state.tick - since >= sim.config.ticks(0.8), inputs.isEmpty {
                    inputs.append(.drop(itemID: item.id, bin: .matching(item.kind)))
                }
            }
            _ = sim.step(inputs: inputs)
        }
        #expect(sim.state.isOver)
        #expect(sim.elapsedSeconds < 12, "took \(sim.elapsedSeconds) s")
    }

    @Test func identicalInputsGiveIdenticalRuns() {
        #expect(BalanceBot.play(seed: 31) == BalanceBot.play(seed: 31))
    }

    @Test func challengeUsesCodeConfigVersion() {
        let code = ChallengeCode(configVersion: 1, seed: 1234)!
        #expect(Simulation.challenge(code)?.config == .v1)
        #expect(Simulation.challenge(ChallengeCode(configVersion: 7, seed: 1)!) == nil)
    }
}
