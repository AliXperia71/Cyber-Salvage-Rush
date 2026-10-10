import SalvageCore
import SpriteKit

final class ItemNode: SKSpriteNode {
    let itemID: Int
    let kind: ItemKind
    /// Positioned by the drag controller, not by state sync.
    var isDragged = false
    /// Dropped on a bin; waiting for the simulation to resolve it.
    var awaitingDrop = false

    private let fuseLabel: SKLabelNode?
    private var lastFuseSecond = -1

    init(itemID: Int, kind: ItemKind, texture: SKTexture, size: CGFloat) {
        self.itemID = itemID
        self.kind = kind
        if kind == .hazardous {
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.fontSize = max(12, size * 0.26)
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: 0, y: -size * 0.52)
            fuseLabel = label
        } else {
            fuseLabel = nil
        }
        let displaySize = size * ProceduralTextureFactory.glowPadding
        super.init(texture: texture, color: .red, size: CGSize(width: displaySize, height: displaySize))
        if let fuseLabel { addChild(fuseLabel) }
        zPosition = 10
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func lift() {
        isDragged = true
        zPosition = 50
        removeAction(forKey: "scale")
        run(.scale(to: 1.18, duration: 0.08), withKey: "scale")
    }

    func settle() {
        isDragged = false
        zPosition = 10
        removeAction(forKey: "scale")
        run(.scale(to: 1, duration: 0.1), withKey: "scale")
    }

    /// Countdown and an urgency pulse as the fuse burns down.
    func updateFuse(ticksRemaining: Int, tickRate: Int, time: TimeInterval) {
        guard let fuseLabel else { return }
        let seconds = Int((Double(ticksRemaining) / Double(tickRate)).rounded(.up))
        if seconds != lastFuseSecond {
            lastFuseSecond = seconds
            fuseLabel.text = "\(seconds)"
            fuseLabel.fontColor = seconds <= 3 ? .systemRed : .white
        }
        let urgency = max(0, 1 - Double(ticksRemaining) / Double(tickRate * 4))
        colorBlendFactor = CGFloat(urgency * (0.5 + 0.5 * sin(time * (6 + 14 * urgency))))
    }
}
