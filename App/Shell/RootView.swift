import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            switch router.screen {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .run(let mode):
                GameContainerView(mode: mode)
                    .id(mode)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.screen)
        .onOpenURL { url in
            // Never interrupt a run; the menu picks this up when it next appears.
            if let link = DeepLink(url: url) { router.pendingLink = link }
        }
    }
}
