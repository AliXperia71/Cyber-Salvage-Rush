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
    /// A challenge to show once the menu is up: from an opened link, or returning from a challenge run.
    var pendingLink: DeepLink?

    init() {
        #if DEBUG
        // `-startRun` / `-startTutorial` skip the menu; used for screenshots and quick iteration.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-startRun") {
            screen = .run(.endless)
        } else if arguments.contains("-startTutorial") {
            screen = .run(.tutorial)
        }
        #endif
    }
}
