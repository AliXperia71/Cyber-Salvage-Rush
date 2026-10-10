import Foundation
import Observation

/// Player preferences and one-time flags. UserDefaults is the right home for these;
/// game progress (credits, unlocks) lives in SwiftData.
@MainActor
@Observable
final class SettingsStore {
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    var tutorialCompleted: Bool {
        didSet { defaults.set(tutorialCompleted, forKey: Keys.tutorial) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let haptics = "settings.hapticsEnabled"
        static let tutorial = "settings.tutorialCompleted"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        tutorialCompleted = defaults.bool(forKey: Keys.tutorial)
    }
}
