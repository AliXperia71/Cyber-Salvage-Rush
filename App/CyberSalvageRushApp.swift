import OSLog
import SwiftData
import SwiftUI

@main
struct CyberSalvageRushApp: App {
    @State private var router = AppRouter()
    @State private var settings = SettingsStore()
    private let container: ModelContainer
    @State private var profile: ProfileRepository

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
        _profile = State(initialValue: ProfileRepository(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(settings)
                .environment(profile)
                .modelContainer(container)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
