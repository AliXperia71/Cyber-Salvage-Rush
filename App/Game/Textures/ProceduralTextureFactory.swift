import SalvageCore
import SpriteKit
import UIKit

/// Draws the neon art once with Core Graphics and caches it as textures.
/// Gameplay uses plain sprites only; live SKShapeNodes are too slow at volume.
@MainActor
final class ProceduralTextureFactory {
    let theme: Theme
    private var cache: [String: SKTexture] = [:]

    init(theme: Theme) {
        self.theme = theme
    }

    /// Texture is larger than `size` to leave room for the glow; display at `itemTextureScale × size`.
    static let glowPadding: CGFloat = 1.5

    func item(_ kind: ItemKind, size: CGFloat) -> SKTexture {
        cached("item.\(kind).\(Int(size))") {
            let canvas = CGSize(width: size * Self.glowPadding, height: size * Self.glowPadding)
            return render(canvas) { ctx in
                let rect = CGRect(origin: .zero, size: canvas).insetBy(dx: (canvas.width - size) / 2, dy: (canvas.height - size) / 2)
                let color = self.theme.color(for: kind)
                let path = Self.shapePath(for: kind, in: rect.insetBy(dx: 3, dy: 3))
                ctx.setShadow(offset: .zero, blur: size * 0.22, color: color.cgColor)
                color.withAlphaComponent(0.28).setFill()
                path.fill()
                color.setStroke()
                path.lineWidth = 3
                path.stroke()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                self.drawSymbol(kind.symbolName, in: rect, pointSize: size * 0.34, offsetY: kind == .hazardous ? size * 0.08 : 0)
            }
        }
    }

    func bin(_ bin: BinID, size: CGSize) -> SKTexture {
        cached("bin.\(bin).\(Int(size.width))x\(Int(size.height))") {
            render(size) { ctx in
                let kind = bin.accepts
                let color = self.theme.color(for: kind)
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
                let panel = UIBezierPath(roundedRect: rect, cornerRadius: 16)
                self.theme.panel.setFill()
                panel.fill()
                ctx.setShadow(offset: .zero, blur: 10, color: color.cgColor)
                color.setStroke()
                panel.lineWidth = 2.5
                panel.stroke()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)

                let iconSize = min(rect.width, rect.height) * 0.42
                let iconRect = CGRect(x: rect.midX - iconSize / 2, y: rect.minY + rect.height * 0.14, width: iconSize, height: iconSize)
                let icon = Self.shapePath(for: kind, in: iconRect)
                color.withAlphaComponent(0.2).setFill()
                icon.fill()
                color.setStroke()
                icon.lineWidth = 2
                icon.stroke()
                self.drawSymbol(kind.symbolName, in: iconRect, pointSize: iconSize * 0.34, offsetY: kind == .hazardous ? iconSize * 0.08 : 0)

                let font = UIFont.monospacedSystemFont(ofSize: max(11, rect.width * 0.12), weight: .heavy)
                let text = NSAttributedString(string: bin.label, attributes: [.font: font, .foregroundColor: color, .kern: 1.5])
                let textSize = text.size()
                text.draw(at: CGPoint(x: rect.midX - textSize.width / 2, y: rect.maxY - rect.height * 0.12 - textSize.height))
            }
        }
    }

    func panel(size: CGSize, cornerRadius: CGFloat = 14) -> SKTexture {
        cached("panel.\(Int(size.width))x\(Int(size.height))") {
            render(size) { _ in
                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2), cornerRadius: cornerRadius)
                self.theme.panel.withAlphaComponent(0.85).setFill()
                path.fill()
                self.theme.panelStroke.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }
    }

    func slot(size: CGFloat) -> SKTexture {
        cached("slot.\(Int(size))") {
            render(CGSize(width: size, height: size)) { _ in
                let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 3, dy: 3), cornerRadius: 10)
                path.setLineDash([6, 5], count: 2, phase: 0)
                self.theme.panelStroke.setStroke()
                path.lineWidth = 2
                path.stroke()
            }
        }
    }

    func chevron(size: CGFloat) -> SKTexture {
        cached("chevron.\(Int(size))") {
            render(CGSize(width: size, height: size)) { _ in
                let path = UIBezierPath()
                path.move(to: CGPoint(x: size * 0.3, y: size * 0.2))
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.8))
                self.theme.beltStripe.setStroke()
                path.lineWidth = size * 0.14
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
    }

    func hand(size: CGFloat) -> SKTexture {
        cached("hand.\(Int(size))") {
            render(CGSize(width: size, height: size)) { ctx in
                ctx.setShadow(offset: .zero, blur: size * 0.15, color: self.theme.standard.cgColor)
                self.drawSymbol("hand.point.up.left.fill", in: CGRect(x: 0, y: 0, width: size, height: size),
                                pointSize: size * 0.6, offsetY: 0)
            }
        }
    }

    /// Soft white dot; tinted per particle.
    func spark() -> SKTexture {
        cached("spark") {
            let size: CGFloat = 32
            return render(CGSize(width: size, height: size)) { ctx in
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                let center = CGPoint(x: size / 2, y: size / 2)
                ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size / 2, options: [])
            }
        }
    }

    // MARK: - Shapes

    static func shapePath(for kind: ItemKind, in rect: CGRect) -> UIBezierPath {
        switch kind {
        case .standard: polygon(sides: 6, in: rect, rotation: 0)
        case .valuable: polygon(sides: 4, in: rect, rotation: -.pi / 2)
        case .hazardous: polygon(sides: 3, in: rect, rotation: -.pi / 2, verticalBias: 0.08)
        }
    }

    private static func polygon(sides: Int, in rect: CGRect, rotation: CGFloat, verticalBias: CGFloat = 0) -> UIBezierPath {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * verticalBias)
        let radius = min(rect.width, rect.height) / 2
        let path = UIBezierPath()
        for index in 0..<sides {
            let angle = rotation + CGFloat(index) * 2 * .pi / CGFloat(sides)
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()
        path.lineJoinStyle = .round
        return path
    }

    // MARK: - Rendering

    private func drawSymbol(_ name: String, in rect: CGRect, pointSize: CGFloat, offsetY: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .black)
        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return }
        let origin = CGPoint(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2 + offsetY)
        image.draw(at: origin)
    }

    private func render(_ size: CGSize, draw: (CGContext) -> Void) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
        return SKTexture(image: image)
    }

    private func cached(_ key: String, make: () -> SKTexture) -> SKTexture {
        if let texture = cache[key] { return texture }
        let texture = make()
        cache[key] = texture
        return texture
    }
}
