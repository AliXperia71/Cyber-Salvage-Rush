import Observation
import SalvageCore

/// Bridges the fixed-step simulation to the frame-driven scene and the SwiftUI HUD.
///
/// The scene calls `advance(by:)` every frame and reacts to the returned events.
/// SwiftUI observes only `hud` and `phase`, which change rarely, never the simulation itself.
@MainActor
@Observable
final class GameController {
    enum Phase: Equatable {
        case playing
        case paused
        case ended(RunSummary)
    }

    struct HUD: Equatable {
        var score = 0
        var overload = 0
        var multiplier = 1
        var combo = 0
        var bufferFull = false
        /// Tutorial only: the kind of the item the player should sort next.
        var tutorialHint: ItemKind?
    }

    private(set) var phase: Phase = .playing
    private(set) var hud = HUD()

    @ObservationIgnored private(set) var simulation: Simulation
    /// State before the latest tick, for interpolating motion between ticks at 120 Hz.
    @ObservationIgnored private(set) var previousState: RunState
    @ObservationIgnored private var accumulator: Double = 0
    @ObservationIgnored private var pendingInputs: [PlayerInput] = []
    @ObservationIgnored private let curve: DifficultyCurve

    init(simulation: Simulation) {
        self.simulation = simulation
        previousState = simulation.state
        curve = DifficultyCurve(config: simulation.config)
    }

    var mode: RunMode { simulation.mode }
    var config: GameConfig { simulation.config }
    var tickDuration: Double { 1 / Double(config.tickRate) }
    /// 0...1 progress from `previousState` toward `simulation.state`.
    var interpolation: Double { accumulator / tickDuration }
    var beltTravelSeconds: Double { curve.travelSeconds(at: simulation.elapsedSeconds) }

    func enqueue(_ input: PlayerInput) {
        guard phase == .playing else { return }
        pendingInputs.append(input)
    }

    /// Runs as many fixed ticks as `frameTime` covers. Long frames are clamped so a hitch
    /// never fast-forwards the player into a loss.
    func advance(by frameTime: Double) -> [GameEvent] {
        guard phase == .playing else { return [] }
        accumulator += min(frameTime, 0.1)
        var events: [GameEvent] = []
        while accumulator >= tickDuration {
            accumulator -= tickDuration
            previousState = simulation.state
            events += simulation.step(inputs: pendingInputs)
            pendingInputs.removeAll()
            if simulation.state.isOver {
                accumulator = 0
                phase = .ended(simulation.summary)
                break
            }
        }
        refreshHUD()
        return events
    }

    func pause() {
        if phase == .playing { phase = .paused }
    }

    func resume() {
        if phase == .paused { phase = .playing }
    }

    private func refreshHUD() {
        let state = simulation.state
        let next = HUD(
            score: state.score,
            overload: Int(state.overload.rounded()),
            multiplier: state.combo.multiplier,
            combo: state.combo.count,
            bufferFull: state.bufferOccupancy >= state.bufferCapacity,
            tutorialHint: mode == .tutorial ? state.items.first?.kind : nil
        )
        if next != hud { hud = next }
    }
}
