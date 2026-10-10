import SalvageCore
import SpriteKit

final class BinNode: SKSpriteNode {
    let bin: BinID

    init(bin: BinID, texture: SKTexture, size: CGSize) {
        self.bin = bin
        super.init(texture: texture, color: .white, size: size)
        zPosition = 5
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setHighlighted(_ highlighted: Bool) {
        guard highlighted != (action(forKey: "hover") != nil) else { return }
        removeAction(forKey: "hover")
        if highlighted {
            run(.repeatForever(.sequence([.scale(to: 1.05, duration: 0.25), .scale(to: 1.0, duration: 0.25)])), withKey: "hover")
        } else {
            run(.scale(to: 1, duration: 0.1))
        }
    }

    func flash(success: Bool) {
        color = success ? .white : .systemRed
        run(.sequence([
            .colorize(withColorBlendFactor: success ? 0.35 : 0.7, duration: 0.04),
            .colorize(withColorBlendFactor: 0, duration: 0.25),
        ]), withKey: "flash")
    }
}
