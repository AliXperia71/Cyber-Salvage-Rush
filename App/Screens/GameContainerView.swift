import SalvageCore
import SpriteKit
import SwiftUI

/// Hosts a run. Retry swaps in a fresh run by changing `runID`.
struct GameContainerView: View {
    let mode: RunMode
    @State private var runID = UUID()

    var body: some View {
        GameRunView(mode: mode, onRetry: { runID = UUID() })
            .id(runID)
    }
}

private struct GameRunView: View {
    let onRetry: () -> Void
    @State private var controller: GameController
    @State private var scene: GameScene
    @State private var isNewBest = false
    @Environment(AppRouter.self) private var router
    @Environment(ScoreStore.self) private var scores
    @Environment(\.scenePhase) private var scenePhase

    init(mode: RunMode, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        let controller = GameController(simulation: Self.makeSimulation(for: mode))
        _controller = State(initialValue: controller)
        _scene = State(initialValue: GameScene(controller: controller, theme: .foundry, haptics: HapticsService()))
    }

    private static func makeSimulation(for mode: RunMode) -> Simulation {
        switch mode {
        case .endless: .endless(seed: .random(in: .min ... .max))
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
                    HUDView(hud: controller.hud, mode: controller.mode, onPause: pause)
                    Spacer()
                }

                overlay
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pause() }
        }
        .onChange(of: controller.phase) { _, phase in
            if case .ended(let summary) = phase, controller.mode == .endless {
                isNewBest = scores.record(endlessScore: summary.score)
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
        case .ended(let summary):
            ResultsView(summary: summary, mode: controller.mode, best: scores.bestEndless, isNewBest: isNewBest,
                        onRetry: onRetry, onMenu: quit)
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

    private func quit() {
        router.screen = .menu
    }
}

private extension UIEdgeInsets {
    init(_ insets: EdgeInsets) {
        self.init(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
    }
}
