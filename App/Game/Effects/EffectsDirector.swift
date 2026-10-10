import SpriteKit
import UIKit

/// Particles, popups, and shake. Respects Reduce Motion.
@MainActor
final class EffectsDirector {
    private let textures: ProceduralTextureFactory
    private weak var layer: SKNode?
    private weak var shakeTarget: SKNode?

    init(textures: ProceduralTextureFactory, layer: SKNode, shakeTarget: SKNode) {
        self.textures = textures
        self.layer = layer
        self.shakeTarget = shakeTarget
    }

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    func burst(at point: CGPoint, color: UIColor, count: Int = 24, speed: CGFloat = 180) {
        guard let layer else { return }
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.spark()
        emitter.numParticlesToEmit = reduceMotion ? count / 3 : count
        emitter.particleBirthRate = 2_000
        emitter.particleLifetime = 0.45
        emitter.particleLifetimeRange = 0.2
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.6
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlphaSpeed = -2.2
        emitter.particleScale = 0.45
        emitter.particleScaleRange = 0.25
        emitter.particleScaleSpeed = -0.6
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.position = point
        emitter.zPosition = 60
        layer.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1), .removeFromParent()]))
    }

    func popup(_ text: String, at point: CGPoint, color: UIColor, size: CGFloat = 20) {
        guard let layer else { return }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        let halfWidth = label.frame.width / 2 + 8
        let sceneWidth = layer.scene?.size.width ?? .greatestFiniteMagnitude
        label.position = CGPoint(x: min(max(point.x, halfWidth), sceneWidth - halfWidth), y: point.y)
        label.zPosition = 70
        layer.addChild(label)
        let rise: SKAction = reduceMotion ? .wait(forDuration: 0.5) : .moveBy(x: 0, y: 46, duration: 0.6)
        label.run(.sequence([.group([rise, .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]), .removeFromParent()]))
    }

    func shake(intensity: CGFloat = 8) {
        guard !reduceMotion, let shakeTarget, shakeTarget.action(forKey: "shake") == nil else { return }
        let steps = (0..<6).map { index -> SKAction in
            let falloff = intensity * CGFloat(6 - index) / 6
            return .moveTo(x: .random(in: -falloff...falloff), duration: 0.03)
        }
        shakeTarget.run(.sequence(steps + [.moveTo(x: 0, duration: 0.03)]), withKey: "shake")
    }
}
