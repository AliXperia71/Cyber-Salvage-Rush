import Testing
@testable import SalvageCore

struct SpawnTests {
    private func take(_ count: Int, seed: UInt64) -> [SpawnEvent] {
        var stream = SpawnStream(seed: seed, config: .v1)
        return (0..<count).map { _ in stream.next()! }
    }

    @Test func sameSeedProducesIdenticalSchedule() {
        #expect(take(500, seed: 99) == take(500, seed: 99))
    }

    @Test func differentSeedsProduceDifferentSchedules() {
        #expect(take(50, seed: 1) != take(50, seed: 2))
    }

    /// Guards against accidental changes to v1 spawning, which would break shipped daily/challenge seeds.
    /// If this fails after an intentional change, add GameConfig.v2 instead of editing v1.
    @Test func goldenScheduleV1() {
        let golden = take(8, seed: 12_345).map { "\($0.tick):\($0.kind.rawValue):\($0.lane)" }
        #expect(golden == GoldenValues.spawnScheduleSeed12345)
    }

    @Test func ticksIncreaseAndIDsAreSequential() {
        let events = take(300, seed: 5)
        #expect(events.map(\.id) == Array(0..<300))
        #expect(zip(events, events.dropFirst()).allSatisfy { $0.tick < $1.tick })
    }

    @Test func hazardRatioWithinBounds() {
        let events = take(2_000, seed: 77)
        let ratio = Double(events.count { $0.kind == .hazardous }) / Double(events.count)
        #expect(ratio > GameConfig.v1.hazardChanceStart * 0.8)
        #expect(ratio < GameConfig.v1.hazardChanceEnd * 1.2)
    }

    @Test func difficultyIsMonotonic() {
        let curve = DifficultyCurve(config: .v1)
        let times = stride(from: 0.0, through: 300, by: 1).map { $0 }
        for (a, b) in zip(times, times.dropFirst()) {
            #expect(curve.spawnInterval(at: b) <= curve.spawnInterval(at: a))
            #expect(curve.travelSeconds(at: b) <= curve.travelSeconds(at: a))
            #expect(curve.hazardChance(at: b) >= curve.hazardChance(at: a))
        }
        #expect(curve.spawnInterval(at: 10_000) >= GameConfig.v1.spawnIntervalEnd * GameConfig.v1.overtimeFloor - 1e-9)
    }

    @Test func tutorialScriptIsOneOfEachKind() {
        var stream = SpawnStream.tutorial(config: .v1)
        var kinds: [ItemKind] = []
        while let event = stream.next() { kinds.append(event.kind) }
        #expect(kinds == [.standard, .valuable, .hazardous])
    }
}
