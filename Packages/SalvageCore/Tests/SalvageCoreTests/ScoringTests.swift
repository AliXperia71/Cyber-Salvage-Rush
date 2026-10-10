import Testing
@testable import SalvageCore

struct ScoringTests {
    @Test(arguments: [(1, 1), (4, 1), (5, 2), (11, 2), (12, 3), (24, 3), (25, 4), (100, 4)])
    func comboMultiplierTiers(sorts: Int, expected: Int) {
        var combo = ComboTracker(tiers: GameConfig.v1.comboTiers)
        for _ in 0..<sorts { _ = combo.registerSuccess() }
        #expect(combo.multiplier == expected)
    }

    @Test func tierUpReportedOnThresholdSort() {
        var combo = ComboTracker(tiers: GameConfig.v1.comboTiers)
        let tierUps = (1...25).filter { _ in combo.registerSuccess().tierUp }
        #expect(tierUps == [5, 12, 25])
    }

    @Test func resetKeepsBest() {
        var combo = ComboTracker(tiers: GameConfig.v1.comboTiers)
        for _ in 0..<7 { _ = combo.registerSuccess() }
        #expect(combo.reset() == 7)
        #expect(combo.count == 0)
        #expect(combo.best == 7)
        #expect(combo.multiplier == 1)
    }

    @Test func pointsAreBaseTimesMultiplier() {
        #expect(ScoreEngine.points(for: .standard, multiplier: 1, config: .v1) == 10)
        #expect(ScoreEngine.points(for: .valuable, multiplier: 3, config: .v1) == 90)
        #expect(ScoreEngine.points(for: .hazardous, multiplier: 4, config: .v1) == 80)
    }
}
