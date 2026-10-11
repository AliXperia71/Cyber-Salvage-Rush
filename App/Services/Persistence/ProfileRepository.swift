import Foundation
import Observation
import SalvageCore
import SwiftData

enum ShopError: Error, Equatable {
    case unknownItem
    case alreadyOwned
    case notOwned
    case insufficientCredits
    case maxed
}

struct RunReward: Equatable {
    var credits: Int
    var dailyBonus: Int
    /// Best and new-best are per context: all-time for Endless, today for Daily, per code for challenges.
    var isNewBest: Bool
    var best: Int
}

extension RunMode {
    var recordKey: String {
        switch self {
        case .endless: "endless"
        case .daily: "daily"
        case .challenge: "challenge"
        case .tutorial: "tutorial"
        }
    }
}

/// The only place that touches SwiftData. Views read the observable mirrors below.
@MainActor
@Observable
final class ProfileRepository {
    private(set) var credits = 0
    private(set) var owned: Set<String> = []
    private(set) var equippedThemeID = "theme.foundry"
    private(set) var equippedDroneID = "drone.spark"
    private(set) var upgrades = UpgradeLevels()
    private(set) var bestEndless = 0
    /// Daily best keyed by `DailySeed.dayKey`. Holds today (loaded at launch) and any day recorded since.
    private(set) var dailyBests: [String: Int] = [:]

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let profile: PlayerProfile
    @ObservationIgnored private let economy: EconomyConfig

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        try makeContainer(ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }

    /// On-disk store at a specific location; used by migration tests.
    static func makeContainer(url: URL) throws -> ModelContainer {
        try makeContainer(ModelConfiguration(url: url))
    }

    private static func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: Schema(versionedSchema: SchemaV2.self),
                           migrationPlan: SalvageMigrationPlan.self,
                           configurations: configuration)
    }

    init(container: ModelContainer, economy: EconomyConfig = .standard) {
        context = container.mainContext
        self.economy = economy
        if let existing = try? context.fetch(FetchDescriptor<PlayerProfile>()).first {
            profile = existing
        } else {
            profile = PlayerProfile()
            context.insert(profile)
        }
        // Newly added free items become owned on the next launch.
        let free = Set(economy.catalog.filter(\.isFree).map(\.id))
        if !free.isSubset(of: Set(profile.ownedCosmeticIDs)) {
            profile.ownedCosmeticIDs = Array(free.union(profile.ownedCosmeticIDs)).sorted()
        }
        save()
        refreshBest()
        let today = DailySeed.dayKey(for: .now)
        dailyBests[today] = bestScore(Self.scope(for: .daily, dayKey: today))
        mirror()
    }

    // MARK: - Runs

    /// Records a finished run and pays out credits. Returns nil for tutorial runs and
    /// for a run ID already recorded, so a view re-firing `.ended` can't double-pay.
    @discardableResult
    func recordRun(id: UUID, summary: RunSummary, mode: RunMode, at date: Date) -> RunReward? {
        guard mode != .tutorial else { return nil }
        var duplicate = FetchDescriptor<RunRecord>(predicate: #Predicate { $0.runID == id })
        duplicate.fetchLimit = 1
        guard ((try? context.fetchCount(duplicate)) ?? 0) == 0 else { return nil }

        let dayKey = DailySeed.dayKey(for: date)
        let scope = Self.scope(for: mode, dayKey: dayKey)
        let previousBest = bestScore(scope)
        let firstRunToday = profile.lastRunDayKey != DailySeed.dayKey(for: date)
        let total = Economy.credits(for: summary, mode: mode, firstRunToday: firstRunToday, config: economy)
        let bonus = firstRunToday ? economy.firstRunOfDayBonus : 0

        let code: String? = if case .challenge(let challenge) = mode { challenge.description } else { nil }
        context.insert(RunRecord(runID: id, modeKey: mode.recordKey, challengeCode: code, seed: summary.seed,
                                 score: summary.score, duration: summary.durationSeconds, date: date))
        profile.credits += total
        profile.runCount += 1
        profile.lastRunDayKey = dayKey
        save()
        refreshBest()
        if mode == .daily { dailyBests[dayKey] = max(previousBest, summary.score) }
        mirror()
        return RunReward(credits: total, dailyBonus: bonus,
                         isNewBest: summary.score > previousBest, best: max(previousBest, summary.score))
    }

    /// Best score for one challenge code, or nil if the player hasn't finished a run of it.
    func bestScore(challenge code: ChallengeCode) -> Int? {
        topScore(Self.scope(for: .challenge(code), dayKey: ""))
    }

    // MARK: - Shop

    func purchase(_ cosmetic: Cosmetic) throws(ShopError) {
        guard let item = economy.catalog.first(where: { $0.id == cosmetic.id }) else { throw .unknownItem }
        guard !owned.contains(item.id) else { throw .alreadyOwned }
        guard profile.credits >= item.price else { throw .insufficientCredits }
        profile.credits -= item.price
        profile.ownedCosmeticIDs.append(item.id)
        apply(equip: item)
        save()
        mirror()
    }

    func equip(_ id: String) throws(ShopError) {
        guard let item = economy.catalog.first(where: { $0.id == id }) else { throw .unknownItem }
        guard owned.contains(id) else { throw .notOwned }
        apply(equip: item)
        save()
        mirror()
    }

    func buyUpgrade(_ upgrade: Upgrade) throws(ShopError) {
        guard let cost = Economy.nextLevelCost(of: upgrade, currentLevel: upgrades[upgrade], config: economy) else { throw .maxed }
        guard profile.credits >= cost else { throw .insufficientCredits }
        profile.credits -= cost
        var levels = profile.upgrades
        levels[upgrade] += 1
        profile.upgrades = levels
        save()
        mirror()
    }

    /// True when at least one unowned cosmetic is within reach.
    var canAffordSomething: Bool {
        economy.catalog.contains { !owned.contains($0.id) && $0.price <= credits }
    }

    // MARK: - Private

    private func apply(equip item: Cosmetic) {
        switch item.kind {
        case .theme: profile.equippedThemeID = item.id
        case .drone: profile.equippedDroneID = item.id
        }
    }

    private func mirror() {
        credits = profile.credits
        owned = Set(profile.ownedCosmeticIDs)
        equippedThemeID = profile.equippedThemeID
        equippedDroneID = profile.equippedDroneID
        upgrades = profile.upgrades
    }

    private func refreshBest() {
        bestEndless = bestScore(Self.scope(for: .endless, dayKey: ""))
    }

    /// The runs a score competes against: all Endless runs, today's dailies, or one challenge code.
    private static func scope(for mode: RunMode, dayKey: String) -> Predicate<RunRecord> {
        let key = mode.recordKey
        switch mode {
        case .daily:
            return #Predicate { $0.modeKey == key && $0.dayKey == dayKey }
        case .challenge(let challenge):
            let code: String? = challenge.description
            return #Predicate { $0.modeKey == key && $0.challengeCode == code }
        case .endless, .tutorial:
            return #Predicate { $0.modeKey == key }
        }
    }

    private func bestScore(_ predicate: Predicate<RunRecord>) -> Int {
        topScore(predicate) ?? 0
    }

    private func topScore(_ predicate: Predicate<RunRecord>) -> Int? {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.score, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.score
    }

    private func save() {
        try? context.save()
    }
}
