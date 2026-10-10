import SpriteKit

final class BufferTrayNode: SKNode {
    private let textures: ProceduralTextureFactory
    private var panel = SKSpriteNode()
    private var slots: [SKSpriteNode] = []
    private let label = SKLabelNode(fontNamed: "Menlo-Bold")

    init(textures: ProceduralTextureFactory) {
        self.textures = textures
        super.init()
        label.text = "BUFFER"
        label.fontSize = 11
        label.fontColor = textures.theme.panelStroke
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .bottom
        addChild(panel)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(_ layout: BoardLayout) {
        let rect = layout.trayRect
        panel.removeFromParent()
        panel = SKSpriteNode(texture: textures.panel(size: rect.size))
        panel.position = CGPoint(x: rect.midX, y: rect.midY)
        panel.color = .systemRed
        insertChild(panel, at: 0)
        label.position = CGPoint(x: rect.minX + 6, y: rect.maxY + 3)

        slots.forEach { $0.removeFromParent() }
        slots = (0..<layout.bufferCapacity).map { slot in
            let node = SKSpriteNode(texture: textures.slot(size: layout.itemSize * 1.15))
            node.position = layout.bufferSlotPosition(slot)
            node.zPosition = 1
            addChild(node)
            return node
        }
    }

    /// Pulses red while the buffer is full and overload is climbing.
    func setFull(_ full: Bool) {
        guard full != (panel.action(forKey: "full") != nil) else { return }
        if full {
            panel.run(.repeatForever(.sequence([
                .colorize(withColorBlendFactor: 0.6, duration: 0.3),
                .colorize(withColorBlendFactor: 0.1, duration: 0.3),
            ])), withKey: "full")
        } else {
            panel.removeAction(forKey: "full")
            panel.run(.colorize(withColorBlendFactor: 0, duration: 0.2))
        }
    }
}
