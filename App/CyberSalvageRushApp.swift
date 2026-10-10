import SwiftUI

@main
struct CyberSalvageRushApp: App {
    @State private var router = AppRouter()
    @State private var scores = ScoreStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(scores)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
