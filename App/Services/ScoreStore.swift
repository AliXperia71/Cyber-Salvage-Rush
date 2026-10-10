import Foundation
import Observation

/// Best scores. Temporary UserDefaults store; replaced by the SwiftData profile in M4.
@MainActor
@Observable
final class ScoreStore {
    private(set) var bestEndless: Int
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestEndless = defaults.integer(forKey: "bestEndless")
    }

    /// Records a score and returns true if it's a new best.
    @discardableResult
    func record(endlessScore score: Int) -> Bool {
        guard score > bestEndless else { return false }
        bestEndless = score
        defaults.set(score, forKey: "bestEndless")
        return true
    }
}
