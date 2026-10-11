import Foundation
import SalvageCore
import SwiftData

typealias PlayerProfile = SchemaV1.PlayerProfile
typealias RunRecord = SchemaV1.RunRecord

/// Versioned from day one so later schema changes get a real migration path.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [PlayerProfile.self, RunRecord.self] }

    /// Singleton: credits, unlocks, and upgrades.
    @Model
    final class PlayerProfile {
        var credits: Int = 0
        var ownedCosmeticIDs: [String] = []
        var equippedThemeID: String = "theme.foundry"
        var equippedDroneID: String = "drone.spark"
        // Plain ints rather than a Codable composite: simpler to migrate.
        var bufferExpansionLevel: Int = 0
        var fuseDampenerLevel: Int = 0
        var comboShieldLevel: Int = 0
        var runCount: Int = 0
        /// `DailySeed.dayKey` of the last recorded run, for the first-run-of-the-day bonus.
        var lastRunDayKey: String?

        init() {}

        var upgrades: UpgradeLevels {
            get {
                UpgradeLevels(bufferExpansion: bufferExpansionLevel, fuseDampener: fuseDampenerLevel,
                              comboShield: comboShieldLevel)
            }
            set {
                bufferExpansionLevel = newValue.bufferExpansion
                fuseDampenerLevel = newValue.fuseDampener
                comboShieldLevel = newValue.comboShield
            }
        }
    }

    @Model
    final class RunRecord {
        @Attribute(.unique) var runID: UUID
        /// `endless` / `daily` / `challenge`; see `RunMode.recordKey`.
        var modeKey: String
        var challengeCode: String?
        /// Bit pattern of the `UInt64` seed; SwiftData has no unsigned 64-bit storage.
        var seed: Int64
        var score: Int
        var duration: Double
        var date: Date
        var dayKey: String

        init(runID: UUID, modeKey: String, challengeCode: String?, seed: UInt64, score: Int, duration: Double, date: Date) {
            self.runID = runID
            self.modeKey = modeKey
            self.challengeCode = challengeCode
            self.seed = Int64(bitPattern: seed)
            self.score = score
            self.duration = duration
            self.date = date
            dayKey = DailySeed.dayKey(for: date)
        }
    }
}

enum SalvageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
