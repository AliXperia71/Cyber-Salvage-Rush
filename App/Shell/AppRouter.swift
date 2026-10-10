import Foundation
import Observation
import SalvageCore

@MainActor
@Observable
final class AppRouter {
    enum Screen: Equatable {
        case menu
        case run(RunMode)
    }

    var screen: Screen = .menu

    init() {
        #if DEBUG
        // `-startRun` skips the menu; used for screenshots and quick iteration.
        if ProcessInfo.processInfo.arguments.contains("-startRun") {
            screen = .run(.endless)
        }
        #endif
    }
}
