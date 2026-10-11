import Foundation
@testable import SalvageCore
import SwiftData
import Testing
@testable import CyberSalvageRush

@MainActor
struct ProfileRepositoryTests {
    private let container = try! ProfileRepository.makeContainer(inMemory: true)
    private let catalog = EconomyConfig.standard.catalog

    private func makeRepository() -> ProfileRepository { ProfileRepository(container: container) }

    private func summary(score: Int) -> RunSummary {
        RunSummary(seed: .max, configVersion: 1, score: score, durationSeconds: 70, bestCombo: 0,
                   standardSorted: 0, valuableSorted: 0, hazardousSorted: 0, missorts: 0, revivesUsed: 0)
    }

    private func item(_ id: String) -> Cosmetic { catalog.first { $0.id == id }! }

    private let day1 = try! Date("2026-10-09T23:59:00Z", strategy: .iso8601)
    private let day2 = try! Date("2026-10-10T00:01:00Z", strategy: .iso8601)

    @Test func freshProfileOwnsAndEquipsFreeItems() {
        let repo = makeRepository()
        #expect(repo.credits == 0)
        #expect(repo.owned == Set(catalog.filter(\.isFree).map(\.id)))
        #expect(repo.equippedThemeID == "theme.foundry")
        #expect(repo.equippedDroneID == "drone.spark")
        #expect(repo.upgrades == UpgradeLevels())
        #expect(repo.bestEndless == 0)
    }

    @Test func dailyBonusOnlyOnFirstRunOfUTCDay() {
        let repo = makeRepository()
        let first = repo.recordRun(id: UUID(), summary: summary(score: 3_000), mode: .endless, at: day1)
        #expect(first?.credits == 60 + 20)
        #expect(first?.dailyBonus == 20)
        let second = repo.recordRun(id: UUID(), summary: summary(score: 3_000), mode: .endless, at: day1)
        #expect(second?.credits == 60)
        #expect(second?.dailyBonus == 0)
        let nextDay = repo.recordRun(id: UUID(), summary: summary(score: 3_000), mode: .daily, at: day2)
        #expect(nextDay?.dailyBonus == 20)
        #expect(repo.credits == 80 + 60 + 80)
    }

    @Test func runIsPaidOnlyOnce() {
        let repo = makeRepository()
        let id = UUID()
        #expect(repo.recordRun(id: id, summary: summary(score: 3_000), mode: .endless, at: day1) != nil)
        #expect(repo.recordRun(id: id, summary: summary(score: 3_000), mode: .endless, at: day1) == nil)
        #expect(repo.credits == 80)
    }

    @Test func tutorialIsNotRecorded() throws {
        let repo = makeRepository()
        #expect(repo.recordRun(id: UUID(), summary: summary(score: 900), mode: .tutorial, at: day1) == nil)
        #expect(repo.credits == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<RunRecord>()) == 0)
    }

    @Test func bestEndlessIgnoresOtherModes() {
        let repo = makeRepository()
        repo.recordRun(id: UUID(), summary: summary(score: 2_000), mode: .endless, at: day1)
        repo.recordRun(id: UUID(), summary: summary(score: 9_000), mode: .daily, at: day1)
        let better = repo.recordRun(id: UUID(), summary: summary(score: 2_500), mode: .endless, at: day1)
        #expect(better?.isNewBest == true)
        let worse = repo.recordRun(id: UUID(), summary: summary(score: 1_000), mode: .endless, at: day1)
        #expect(worse?.isNewBest == false)
        #expect(worse?.best == 2_500)
        #expect(repo.bestEndless == 2_500)
    }

    @Test func seedRoundTripsThroughSignedStorage() throws {
        let repo = makeRepository()
        repo.recordRun(id: UUID(), summary: summary(score: 100), mode: .endless, at: day1)
        let record = try #require(try container.mainContext.fetch(FetchDescriptor<RunRecord>()).first)
        #expect(UInt64(bitPattern: record.seed) == .max)
        #expect(record.dayKey == "20261009")
    }

    @Test func purchaseRules() {
        let repo = makeRepository()
        let neonTide = item("theme.neonTide")
        #expect(throws: ShopError.insufficientCredits) { try repo.purchase(neonTide) }
        #expect(throws: ShopError.alreadyOwned) { try repo.purchase(item("theme.foundry")) }

        repo.recordRun(id: UUID(), summary: summary(score: 10_000), mode: .endless, at: day1) // 200 + 20
        #expect(throws: Never.self) { try repo.purchase(neonTide) }
        #expect(repo.credits == 220 - 150)
        #expect(repo.owned.contains(neonTide.id))
        #expect(repo.equippedThemeID == neonTide.id)
        #expect(repo.equippedDroneID == "drone.spark")
    }

    @Test func equipRequiresOwnership() {
        let repo = makeRepository()
        #expect(throws: ShopError.notOwned) { try repo.equip("drone.halo") }
        #expect(throws: ShopError.unknownItem) { try repo.equip("drone.nope") }
        #expect(repo.equippedDroneID == "drone.spark")
    }

    @Test func upgradesStopAtMaxAndFeedModifiers() {
        let repo = makeRepository()
        #expect(throws: ShopError.insufficientCredits) { try repo.buyUpgrade(.bufferExpansion) }
        repo.recordRun(id: UUID(), summary: summary(score: 100_000), mode: .endless, at: day1) // 2_020
        #expect(throws: Never.self) { try repo.buyUpgrade(.bufferExpansion) }
        #expect(throws: Never.self) { try repo.buyUpgrade(.bufferExpansion) }
        #expect(throws: ShopError.maxed) { try repo.buyUpgrade(.bufferExpansion) }
        #expect(repo.credits == 2_020 - 400 - 1_200)
        #expect(Economy.modifiers(for: repo.upgrades, mode: .endless).bufferBonus == 2)
        #expect(Economy.modifiers(for: repo.upgrades, mode: .daily) == .none)
    }

    @Test func progressSurvivesNewRepository() throws {
        let repo = makeRepository()
        repo.recordRun(id: UUID(), summary: summary(score: 20_000), mode: .endless, at: day1)
        try repo.purchase(item("theme.neonTide"))
        try repo.buyUpgrade(.fuseDampener)

        let reloaded = makeRepository()
        #expect(reloaded.equippedThemeID == "theme.neonTide")
        #expect(reloaded.credits == repo.credits)
        #expect(reloaded.upgrades.fuseDampener == 1)
        #expect(reloaded.bestEndless == 20_000)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PlayerProfile>()) == 1)
    }

    /// Exit criteria: Neon Tide within about two median runs (bot median ≈ 50–100 credits/run).
    @Test func firstUnlockWithinTwoTypicalRuns() {
        let repo = makeRepository()
        repo.recordRun(id: UUID(), summary: summary(score: 3_250), mode: .endless, at: day1)
        repo.recordRun(id: UUID(), summary: summary(score: 3_250), mode: .endless, at: day1)
        #expect(repo.credits >= item("theme.neonTide").price)
    }
}

@MainActor
struct CosmeticArtTests {
    @Test func everyCatalogThemeHasAPalette() {
        let catalogThemes = EconomyConfig.standard.catalog.filter { $0.kind == .theme }.map(\.id)
        #expect(Set(catalogThemes) == Set(Theme.all.map(\.id)))
        #expect(catalogThemes.count == Theme.all.count)
    }

    @Test func everyCatalogDroneHasArt() {
        let catalogDrones = EconomyConfig.standard.catalog.filter { $0.kind == .drone }.map(\.id)
        #expect(Set(catalogDrones) == Set(DroneNode.designs))
    }
}
