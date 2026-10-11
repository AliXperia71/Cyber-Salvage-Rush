import Foundation
@testable import SalvageCore
import SwiftData
import Testing
@testable import CyberSalvageRush

@MainActor
struct ChallengeRepositoryTests {
    private let container = try! ProfileRepository.makeContainer(inMemory: true)
    private let profile: ProfileRepository
    private let challenges: ChallengeRepository
    private let code = ChallengeCode(configVersion: 1, seed: 42)!
    private let other = ChallengeCode(configVersion: 1, seed: 43)!

    init() {
        profile = ProfileRepository(container: container)
        challenges = ChallengeRepository(container: container, profile: profile)
    }

    private func summary(score: Int) -> RunSummary {
        RunSummary(seed: code.simulationSeed, configVersion: 1, score: score, durationSeconds: 70, bestCombo: 0,
                   standardSorted: 0, valuableSorted: 0, hazardousSorted: 0, missorts: 0, revivesUsed: 0)
    }

    @Test func trackIsIdempotentAndOrdersByActivity() {
        challenges.track(code, at: Date(timeIntervalSince1970: 100))
        challenges.track(other, at: Date(timeIntervalSince1970: 200))
        challenges.track(code, at: Date(timeIntervalSince1970: 300))
        #expect(challenges.challenges.map(\.code) == [code, other])
        #expect(challenges.challenges.first?.myBest == nil)
    }

    @Test func resultsAreSortedNamedAndDeduplicated() throws {
        try challenges.addResult(ResultCode(challenge: code, score: 900)!, name: "  Sam ")
        try challenges.addResult(ResultCode(challenge: code, score: 1_500)!, name: "")
        #expect(throws: ChallengeError.duplicateResult) {
            try challenges.addResult(ResultCode(challenge: code, score: 900)!, name: "Again")
        }
        let friends = try #require(challenges.summary(for: code)).friends
        #expect(friends.map(\.score) == [1_500, 900])
        #expect(friends.map(\.name) == [nil, "Sam"])
    }

    @Test func addingAResultForAnUnknownChallengeTracksIt() throws {
        try challenges.addResult(ResultCode(challenge: other, score: 10)!, name: nil)
        #expect(challenges.summary(for: other)?.friends.count == 1)
    }

    @Test func myBestComesFromRecordedChallengeRuns() {
        challenges.track(code)
        profile.recordRun(id: UUID(), summary: summary(score: 700), mode: .challenge(code), at: .now)
        profile.recordRun(id: UUID(), summary: summary(score: 1_200), mode: .challenge(code), at: .now)
        profile.recordRun(id: UUID(), summary: summary(score: 9_999), mode: .challenge(other), at: .now)
        profile.recordRun(id: UUID(), summary: summary(score: 9_999), mode: .endless, at: .now)
        challenges.refresh()
        #expect(challenges.summary(for: code)?.myBest == 1_200)
    }

    @Test func deleteCascadesToResults() throws {
        try challenges.addResult(ResultCode(challenge: code, score: 5)!, name: nil)
        challenges.delete(code)
        #expect(challenges.challenges.isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<ChallengeResult>()) == 0)
    }
}

@MainActor
struct MigrationTests {
    /// An M4 (SchemaV1) store must open under the current schema with progress intact.
    @Test func v1StoreMigratesToCurrentSchema() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let v1 = try ModelContainer(for: Schema(versionedSchema: SchemaV1.self), configurations: ModelConfiguration(url: url))
            let profile = SchemaV1.PlayerProfile()
            profile.credits = 321
            profile.equippedThemeID = "theme.neonTide"
            v1.mainContext.insert(profile)
            v1.mainContext.insert(SchemaV1.RunRecord(runID: UUID(), modeKey: "endless", challengeCode: nil,
                                                     seed: 1, score: 4_000, duration: 60, date: .now))
            try v1.mainContext.save()
        }

        let container = try ProfileRepository.makeContainer(url: url)
        let profile = ProfileRepository(container: container)
        #expect(profile.credits == 321)
        #expect(profile.equippedThemeID == "theme.neonTide")
        #expect(profile.bestEndless == 4_000)

        let challenges = ChallengeRepository(container: container, profile: profile)
        challenges.track(ChallengeCode(configVersion: 1, seed: 7)!)
        #expect(challenges.challenges.count == 1)
    }
}
