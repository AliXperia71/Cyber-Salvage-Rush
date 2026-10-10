import SalvageCore
import SwiftUI

struct HUDView: View {
    let hud: GameController.HUD
    let mode: RunMode
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title3.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Palette.panel, in: .circle)
                        .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))
                }
                .foregroundStyle(Palette.text)
                .accessibilityLabel("Pause")

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(hud.score.formatted())
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .contentTransition(.numericText(value: Double(hud.score)))
                        .animation(.snappy(duration: 0.2), value: hud.score)
                        .foregroundStyle(Palette.text)
                    if mode == .daily {
                        Text("DAILY")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(Palette.gold)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score \(hud.score)")

                ComboBadge(multiplier: hud.multiplier, combo: hud.combo)
                    .padding(.leading, 10)
            }

            OverloadBar(value: hud.overload)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

private struct ComboBadge: View {
    let multiplier: Int
    let combo: Int

    var body: some View {
        Text("×\(multiplier)")
            .font(.system(.title2, design: .monospaced).weight(.black))
            .foregroundStyle(multiplier > 1 ? Palette.background : Palette.stroke)
            .frame(width: 58, height: 44)
            .background(multiplier > 1 ? Palette.gold : Palette.panel, in: .rect(cornerRadius: 10))
            .scaleEffect(multiplier > 1 ? 1.05 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.5), value: multiplier)
            .accessibilityLabel("Combo multiplier \(multiplier), streak \(combo)")
    }
}

private struct OverloadBar: View {
    let value: Int

    private var color: Color {
        switch value {
        case ..<50: Palette.cyan
        case ..<80: Palette.gold
        default: Palette.danger
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("OVERLOAD")
                .font(.system(.caption2, design: .monospaced).weight(.heavy))
                .foregroundStyle(Palette.stroke)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.panel)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * CGFloat(value) / 100)
                        .shadow(color: color.opacity(0.8), radius: 6)
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.15), value: value)
            Text("\(value)%")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overload \(value) percent")
    }
}
