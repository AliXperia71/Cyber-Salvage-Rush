import SwiftUI

/// SwiftUI mirror of the active theme for menus and HUD.
@MainActor
enum Palette {
    static var background: Color { Color(uiColor: Theme.foundry.background) }
    static var panel: Color { Color(uiColor: Theme.foundry.panel) }
    static var stroke: Color { Color(uiColor: Theme.foundry.panelStroke) }
    static var cyan: Color { Color(uiColor: Theme.foundry.standard) }
    static var gold: Color { Color(uiColor: Theme.foundry.valuable) }
    static var magenta: Color { Color(uiColor: Theme.foundry.hazardous) }
    static var danger: Color { Color(uiColor: Theme.foundry.danger) }
    static var text: Color { Color(uiColor: Theme.foundry.text) }
}

/// Primary neon button used across menus.
struct NeonButtonStyle: ButtonStyle {
    var color: Color = Palette.cyan
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .monospaced).weight(.heavy))
            .tracking(1.5)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(prominent ? Palette.background : color)
            .background(prominent ? color : color.opacity(0.08), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: prominent ? 0 : 1.5))
            .shadow(color: color.opacity(prominent ? 0.55 : 0), radius: 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
