import OSLog
import SwiftData
import SwiftUI

@main
struct CyberSalvageRushApp: App {
    @State private var router = AppRouter()
    @State private var settings = SettingsStore()
    private let container: ModelContainer
    @State private var profile: ProfileRepository
    @State private var challenges: ChallengeRepository

    init() {
        var inMemory = false
        #if DEBUG
        // `-freshProfile` simulates a fresh install without wiping the real store.
        inMemory = ProcessInfo.processInfo.arguments.contains("-freshProfile")
        #endif
        let container: ModelContainer
        do {
            container = try ProfileRepository.makeContainer(inMemory: inMemory)
        } catch {
            // Losing progress for one session beats crashing on launch.
            Logger(subsystem: "com.aliaamir.CyberSalvageRush", category: "persistence")
                .error("Store failed to open, using in-memory: \(error)")
            container = try! ProfileRepository.makeContainer(inMemory: true)
        }
        self.container = container
        let profile = ProfileRepository(container: container)
        _profile = State(initialValue: profile)
        _challenges = State(initialValue: ChallengeRepository(container: container, profile: profile))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(settings)
                .environment(profile)
                .environment(challenges)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
