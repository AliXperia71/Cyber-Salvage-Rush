import SpriteKit

/// A belt strip with chevrons scrolling at the simulation's belt speed.
final class ConveyorNode: SKNode {
    private let belt: SKSpriteNode
    private var chevrons: [SKSpriteNode] = []
    private let spacing: CGFloat
    private var width: CGFloat = 0

    init(textures: ProceduralTextureFactory, height: CGFloat) {
        belt = SKSpriteNode(color: textures.theme.belt, size: CGSize(width: 1, height: height))
        spacing = height * 0.9
        super.init()
        addChild(belt)
        let chevronTexture = textures.chevron(size: height * 0.6)
        for _ in 0..<40 {
            let chevron = SKSpriteNode(texture: chevronTexture)
            chevron.zPosition = 1
            chevrons.append(chevron)
            addChild(chevron)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func layout(width: CGFloat) {
        self.width = width
        belt.size.width = width
        belt.position = CGPoint(x: width / 2, y: 0)
        for (index, chevron) in chevrons.enumerated() {
            chevron.position = CGPoint(x: CGFloat(index) * spacing, y: 0)
            chevron.isHidden = chevron.position.x > width
        }
    }

    func scroll(by distance: CGFloat) {
        let span = spacing * CGFloat(chevrons.count)
        for chevron in chevrons {
            var x = chevron.position.x + distance
            if x > span { x -= span }
            chevron.position.x = x
            chevron.isHidden = x > width
        }
    }
}
