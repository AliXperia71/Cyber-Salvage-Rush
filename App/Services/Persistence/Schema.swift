import Foundation
import SalvageCore
import SwiftData

// Unchanged models keep their V1 definitions; only new or changed ones get a new nested type.
typealias PlayerProfile = SchemaV1.PlayerProfile
typealias RunRecord = SchemaV1.RunRecord
typealias ChallengeEntry = SchemaV2.ChallengeEntry
typealias ChallengeResult = SchemaV2.ChallengeResult

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

/// Adds friend challenges.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.PlayerProfile.self, SchemaV1.RunRecord.self, ChallengeEntry.self, ChallengeResult.self]
    }

    /// A challenge the player created, joined, or received results for.
    /// The player's own best comes from `RunRecord.challengeCode`, not from here.
    @Model
    final class ChallengeEntry {
        @Attribute(.unique) var code: String
        var createdAt: Date
        var lastActivity: Date
        @Relationship(deleteRule: .cascade, inverse: \ChallengeResult.challenge)
        var results: [ChallengeResult] = []

        init(code: String, date: Date) {
            self.code = code
            createdAt = date
            lastActivity = date
        }
    }

    /// A friend's score, pasted in from their `ResultCode`.
    @Model
    final class ChallengeResult {
        var resultCode: String
        var name: String?
        var score: Int
        var addedAt: Date
        var challenge: ChallengeEntry?

        init(resultCode: String, name: String?, score: Int, addedAt: Date) {
            self.resultCode = resultCode
            self.name = name
            self.score = score
            self.addedAt = addedAt
        }
    }
}

enum SalvageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
