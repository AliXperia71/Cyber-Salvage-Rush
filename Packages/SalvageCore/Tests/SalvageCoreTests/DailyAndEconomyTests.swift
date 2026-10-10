import Foundation
import Testing
@testable import SalvageCore

struct DailySeedTests {
    private func utc(_ string: String) -> Date {
        try! Date(string, strategy: .iso8601)
    }

    @Test func sameUTCDayGivesSameSeed() {
        #expect(DailySeed.seed(for: utc("2026-10-09T00:00:00Z")) == DailySeed.seed(for: utc("2026-10-09T23:59:59Z")))
        #expect(DailySeed.dayKey(for: utc("2026-10-09T12:00:00Z")) == "20261009")
    }

    @Test func rollsOverAtUTCMidnight() {
        #expect(DailySeed.seed(for: utc("2026-10-09T23:59:59Z")) != DailySeed.seed(for: utc("2026-10-10T00:00:00Z")))
        #expect(DailySeed.nextReset(after: utc("2026-10-09T15:30:00Z")) == utc("2026-10-10T00:00:00Z"))
    }

    @Test func seedIsStable() {
        #expect(DailySeed.seed(for: utc("2026-10-09T12:00:00Z")) == StableHash.fnv1a("CSR-daily-v1-20261009"))
    }
}

struct EconomyTests {
    private func summary(score: Int) -> RunSummary {
        RunSummary(seed: 0, configVersion: 1, score: score, durationSeconds: 60, bestCombo: 0,
                   standardSorted: 0, valuableSorted: 0, hazardousSorted: 0, missorts: 0, revivesUsed: 0)
    }

    @Test func creditsFormula() {
        #expect(Economy.credits(for: summary(score: 3_000), mode: .endless, firstRunToday: false) == 60)
        #expect(Economy.credits(for: summary(score: 3_000), mode: .daily, firstRunToday: true) == 80)
        #expect(Economy.credits(for: summary(score: 3_000), mode: .tutorial, firstRunToday: true) == 0)
    }

    @Test func modifiersOnlyInEndless() {
        let levels = UpgradeLevels(bufferExpansion: 2, fuseDampener: 3, comboShield: 1)
        #expect(Economy.modifiers(for: levels, mode: .endless) == RunModifiers(bufferBonus: 2, fuseMultiplier: 1.15, comboShields: 1))
        #expect(Economy.modifiers(for: levels, mode: .daily) == .none)
        #expect(Economy.modifiers(for: levels, mode: .challenge(ChallengeCode(configVersion: 1, seed: 1)!)) == .none)
    }

    @Test func upgradeCostsAndMaxLevels() {
        #expect(Economy.nextLevelCost(of: .fuseDampener, currentLevel: 0) == 250)
        #expect(Economy.nextLevelCost(of: .fuseDampener, currentLevel: 3) == nil)
        #expect(Economy.maxLevel(of: .bufferExpansion) == 2)
    }

    @Test func catalogHasFreeStarterOfEachKind() {
        let catalog = EconomyConfig.standard.catalog
        #expect(catalog.contains { $0.kind == .theme && $0.isFree })
        #expect(catalog.contains { $0.kind == .drone && $0.isFree })
        #expect(Set(catalog.map(\.id)).count == catalog.count)
    }
}
