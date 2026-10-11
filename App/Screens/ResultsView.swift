import SalvageCore
import SwiftUI

struct ResultsView: View {
    let summary: RunSummary
    let mode: RunMode
    /// Nil only for a moment before the run is recorded.
    let reward: RunReward?
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("SYSTEM OVERLOAD")
                    .font(.system(.title3, design: .monospaced).weight(.heavy))
                    .foregroundStyle(Palette.danger)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 4) {
                    Text(summary.score.formatted())
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(Palette.text)
                        .minimumScaleFactor(0.5)
                    if reward?.isNewBest == true {
                        Text("NEW BEST")
                            .font(.system(.headline, design: .monospaced).weight(.black))
                            .foregroundStyle(Palette.background)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.gold, in: .capsule)
                    } else if mode == .endless, let best = reward?.best, best > 0 {
                        Text("BEST \(best.formatted())")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold))
                            .foregroundStyle(Palette.gold)
                    }
                }
                .accessibilityElement(children: .combine)

                if let reward, reward.credits > 0 {
                    VStack(spacing: 2) {
                        Label("+\(reward.credits.formatted()) CREDITS", systemImage: "circle.hexagongrid.fill")
                            .font(.system(.headline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(Palette.gold)
                        if reward.dailyBonus > 0 {
                            Text("incl. +\(reward.dailyBonus) first run today")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Palette.stroke)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                HStack(spacing: 0) {
                    Stat(title: "SORTED", value: "\(summary.totalSorted)")
                    Stat(title: "BEST COMBO", value: "\(summary.bestCombo)")
                    Stat(title: "TIME", value: Duration.seconds(summary.durationSeconds).formatted(.time(pattern: .minuteSecond)))
                }
                .padding(.vertical, 12)
                .background(Palette.panel.opacity(0.9), in: .rect(cornerRadius: 14))

                Button(action: onRetry) {
                    Label("RETRY", systemImage: "arrow.clockwise")
                }
                .buttonStyle(NeonButtonStyle())
                .keyboardShortcut(.defaultAction)

                Button("MENU", action: onMenu)
                    .buttonStyle(NeonButtonStyle(color: Palette.stroke, prominent: false))
            }
            .padding(24)
            .background(Palette.background.opacity(0.95), in: .rect(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.danger.opacity(0.6), lineWidth: 1.5))
            .shadow(color: Palette.danger.opacity(0.35), radius: 24)
            .padding(20)
        }
    }
}

private struct Stat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(Palette.text)
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(Palette.stroke)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
