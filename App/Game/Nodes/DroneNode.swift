import SalvageCore
import SpriteKit
import UIKit

/// A cosmetic companion that hovers beside the tray and reacts to play.
final class DroneNode: SKSpriteNode {
    /// IDs with baked art; must match the drone entries in `EconomyConfig.standard.catalog`.
    static let designs = ["drone.spark", "drone.magpie", "drone.warden", "drone.halo"]

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(texture: SKTexture, size: CGFloat) {
        super.init(texture: texture, color: .white, size: CGSize(width: size, height: size))
        zPosition = 8
        alpha = 0.9
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Gentle hover; skipped under Reduce Motion.
    func startHovering() {
        guard !reduceMotion else { return }
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 6, duration: 0.9),
            .moveBy(x: 0, y: -6, duration: 0.9),
        ])
        bob.timingMode = .easeInEaseOut
        run(.repeatForever(bob), withKey: "hover")
    }

    func react(to event: GameEvent) {
        switch event {
        case .comboTierUp:
            removeAction(forKey: "react")
            let pulse = SKAction.sequence([.scale(to: 1.35, duration: 0.12), .scale(to: 1, duration: 0.2)])
            let action: SKAction = reduceMotion ? pulse : .group([pulse, .rotate(byAngle: .pi * 2, duration: 0.4)])
            run(action, withKey: "react")
        case .sorted:
            guard action(forKey: "react") == nil else { return }
            run(.sequence([.fadeAlpha(to: 1, duration: 0.04), .fadeAlpha(to: 0.9, duration: 0.2)]), withKey: "react")
        case .missorted, .hazardExpired:
            guard !reduceMotion else {
                run(.sequence([.fadeAlpha(to: 0.4, duration: 0.1), .fadeAlpha(to: 0.9, duration: 0.3)]), withKey: "react")
                return
            }
            run(.sequence([.rotate(byAngle: 0.35, duration: 0.05), .rotate(byAngle: -0.7, duration: 0.1),
                           .rotate(toAngle: 0, duration: 0.1)]), withKey: "react")
        default:
            break
        }
    }
}
