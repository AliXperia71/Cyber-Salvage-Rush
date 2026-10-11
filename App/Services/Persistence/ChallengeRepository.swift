import Foundation
import Observation
import SalvageCore
import SwiftData

struct FriendScore: Identifiable, Equatable {
    /// The pasted result code; also what makes a result a duplicate.
    let id: String
    let name: String?
    let score: Int
}

struct ChallengeSummary: Identifiable, Equatable {
    let code: ChallengeCode
    let lastActivity: Date
    /// Nil until the player finishes a run of this challenge.
    let myBest: Int?
    /// Highest first.
    let friends: [FriendScore]

    var id: String { code.description }
}

enum ChallengeError: Error, Equatable {
    case duplicateResult
}

/// Friend challenges: codes the player created or joined, plus friends' pasted results.
@MainActor
@Observable
final class ChallengeRepository {
    /// Most recent activity first.
    private(set) var challenges: [ChallengeSummary] = []

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let profile: ProfileRepository

    init(container: ModelContainer, profile: ProfileRepository) {
        context = container.mainContext
        self.profile = profile
        refresh()
    }

    func summary(for code: ChallengeCode) -> ChallengeSummary? {
        challenges.first { $0.code == code }
    }

    /// Creates the entry if needed and marks it as recently used.
    func track(_ code: ChallengeCode, at date: Date = .now) {
        let entry = entry(for: code) ?? {
            let entry = ChallengeEntry(code: code.description, date: date)
            context.insert(entry)
            return entry
        }()
        entry.lastActivity = max(entry.lastActivity, date)
        save()
    }

    func addResult(_ result: ResultCode, name: String?, at date: Date = .now) throws(ChallengeError) {
        track(result.challenge, at: date)
        guard let entry = entry(for: result.challenge) else { return }
        let text = result.description
        guard !entry.results.contains(where: { $0.resultCode == text }) else { throw .duplicateResult }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let added = ChallengeResult(resultCode: text, name: trimmed?.isEmpty == false ? trimmed : nil,
                                    score: result.score, addedAt: date)
        entry.results.append(added)
        save()
    }

    func delete(_ code: ChallengeCode) {
        guard let entry = entry(for: code) else { return }
        context.delete(entry)
        save()
    }

    /// Re-reads the player's own bests, which change whenever a challenge run is recorded.
    func refresh() {
        let descriptor = FetchDescriptor<ChallengeEntry>(sortBy: [SortDescriptor(\.lastActivity, order: .reverse)])
        let entries = (try? context.fetch(descriptor)) ?? []
        challenges = entries.compactMap { entry in
            guard let code = ChallengeCode(entry.code) else { return nil }
            let friends = entry.results
                .map { FriendScore(id: $0.resultCode, name: $0.name, score: $0.score) }
                .sorted { $0.score > $1.score }
            return ChallengeSummary(code: code, lastActivity: entry.lastActivity,
                                    myBest: profile.bestScore(challenge: code), friends: friends)
        }
    }

    private func entry(for code: ChallengeCode) -> ChallengeEntry? {
        let text = code.description
        var descriptor = FetchDescriptor<ChallengeEntry>(predicate: #Predicate { $0.code == text })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        try? context.save()
        refresh()
    }
}
