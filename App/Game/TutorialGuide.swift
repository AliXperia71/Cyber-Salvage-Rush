import SpriteKit

/// The ghost hand that demonstrates dragging the waiting item to its bin.
/// Shows right away for the first item, then only if the player hesitates.
@MainActor
final class TutorialGuide {
    private let hand: SKSpriteNode
    private var demoTargetID: Int?
    private var idleTime: TimeInterval = 0
    private var hasSortedOnce = false

    init(texture: SKTexture, size: CGFloat, layer: SKNode) {
        hand = SKSpriteNode(texture: texture)
        hand.size = CGSize(width: size, height: size)
        // The fingertip of "hand.point.up.left" sits near the texture's top-left.
        hand.anchorPoint = CGPoint(x: 0.3, y: 0.85)
        hand.zPosition = 90
        hand.alpha = 0
        layer.addChild(hand)
    }

    func noteSorted() {
        hasSortedOnce = true
        idleTime = 0
        hide()
    }

    /// `target` is the waiting item's ID with its resting position and destination, or nil while nothing is waiting.
    func update(frameTime: TimeInterval, target: (id: Int, from: CGPoint, to: CGPoint)?, isDragging: Bool) {
        guard let target, !isDragging else {
            idleTime = 0
            hide()
            return
        }
        idleTime += frameTime
        let delay: TimeInterval = hasSortedOnce ? 1.5 : 0.3
        guard idleTime >= delay, demoTargetID != target.id else { return }
        demoTargetID = target.id
        hand.removeAllActions()
        hand.position = target.from
        hand.alpha = 0
        let drag = SKAction.move(to: target.to, duration: 0.8)
        drag.timingMode = .easeInEaseOut
        hand.run(.repeatForever(.sequence([
            .move(to: target.from, duration: 0),
            .fadeIn(withDuration: 0.15),
            .scale(to: 0.9, duration: 0.12),
            drag,
            .scale(to: 1, duration: 0.12),
            .fadeOut(withDuration: 0.2),
            .wait(forDuration: 0.35),
        ])))
    }

    private func hide() {
        guard demoTargetID != nil else { return }
        demoTargetID = nil
        hand.removeAllActions()
        hand.run(.fadeOut(withDuration: 0.1))
    }
}
