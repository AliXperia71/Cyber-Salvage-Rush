import SwiftUI

@main
struct CyberSalvageRushApp: App {
    @State private var router = AppRouter()
    @State private var scores = ScoreStore()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(scores)
                .environment(settings)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
