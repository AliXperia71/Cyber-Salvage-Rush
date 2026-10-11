import SalvageCore
import SpriteKit
import SwiftUI

/// Hosts a run. Retry swaps in a fresh run by changing `runID`.
struct GameContainerView: View {
    let mode: RunMode
    @State private var runID = UUID()
    /// Snapshot per run: profile changes mid-run (e.g. credits on run end) must not rebuild the scene.
    @State private var loadout: Loadout?
    @Environment(ProfileRepository.self) private var profile

    var body: some View {
        if let loadout {
            GameRunView(mode: mode, loadout: loadout, onRetry: {
                self.loadout = makeLoadout()
                runID = UUID()
            })
            .id(runID)
        } else {
            Color.clear.onAppear { loadout = makeLoadout() }
        }
    }

    private func makeLoadout() -> Loadout {
        Loadout(theme: Theme.with(id: profile.equippedThemeID),
                droneID: mode == .tutorial ? nil : profile.equippedDroneID,
                modifiers: Economy.modifiers(for: profile.upgrades, mode: mode))
    }
}

/// What the player brings into a run from the shop.
struct Loadout {
    var theme: Theme
    var droneID: String?
    var modifiers: RunModifiers
}

private struct GameRunView: View {
    let onRetry: () -> Void
    @State private var controller: GameController
    @State private var scene: GameScene
    @State private var reward: RunReward?
    /// Identifies this run for idempotent recording; retry rebuilds the view and gets a new one.
    private let runID = UUID()
    @Environment(AppRouter.self) private var router
    @Environment(ProfileRepository.self) private var profile
    @Environment(\.scenePhase) private var scenePhase

    @Environment(SettingsStore.self) private var settings

    init(mode: RunMode, loadout: Loadout, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        let controller = GameController(simulation: Self.makeSimulation(for: mode, modifiers: loadout.modifiers))
        _controller = State(initialValue: controller)
        _scene = State(initialValue: GameScene(controller: controller, theme: loadout.theme, droneID: loadout.droneID,
                                               haptics: HapticsService()))
    }

    private static func makeSimulation(for mode: RunMode, modifiers: RunModifiers) -> Simulation {
        switch mode {
        case .endless: .endless(seed: .random(in: .min ... .max), modifiers: modifiers)
        case .daily: .daily(for: .now)
        case .challenge(let code): .challenge(code) ?? .endless(seed: code.simulationSeed)
        case .tutorial: .tutorial()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .onAppear { scene.insets = UIEdgeInsets(proxy.safeAreaInsets) }
                    .onChange(of: proxy.safeAreaInsets) { _, insets in scene.insets = UIEdgeInsets(insets) }

                VStack {
                    if controller.mode == .tutorial {
                        TutorialHUDView(hint: controller.hud.tutorialHint, onSkip: finishTutorial)
                    } else {
                        HUDView(hud: controller.hud, mode: controller.mode, onPause: pause)
                    }
                    Spacer()
                }

                overlay
            }
        }
        .onAppear { scene.hapticsEnabled = settings.hapticsEnabled }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pause() }
        }
        .onChange(of: controller.phase) { _, phase in
            guard case .ended(let summary) = phase else { return }
            if controller.mode == .tutorial {
                settings.tutorialCompleted = true
            } else {
                reward = profile.recordRun(id: runID, summary: summary, mode: controller.mode, at: .now)
            }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch controller.phase {
        case .playing:
            EmptyView()
        case .paused:
            PauseView(onResume: resume, onQuit: quit)
                .transition(.opacity)
        case .ended where controller.mode == .tutorial:
            TutorialCompleteView(onContinue: finishTutorial)
                .transition(.opacity)
        case .ended(let summary):
            ResultsView(summary: summary, mode: controller.mode, reward: reward, onRetry: onRetry, onMenu: quit)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private func pause() {
        guard controller.phase == .playing else { return }
        scene.releaseAllDrags()
        controller.pause()
    }

    private func resume() {
        scene.resetClock()
        controller.resume()
    }

    /// Tutorial finished or skipped: go straight into a real run.
    private func finishTutorial() {
        settings.tutorialCompleted = true
        router.screen = .run(.endless)
    }

    private func quit() {
        router.screen = .menu
    }
}

private extension UIEdgeInsets {
    init(_ insets: EdgeInsets) {
        self.init(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}
