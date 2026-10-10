import SalvageCore
import SwiftUI

struct MainMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ScoreStore.self) private var scores

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 6) {
                Text("CYBER")
                    .foregroundStyle(Palette.cyan)
                Text("SALVAGE")
                    .foregroundStyle(Palette.text)
                Text("RUSH")
                    .foregroundStyle(Palette.magenta)
            }
            .font(.system(size: 48, weight: .black, design: .monospaced))
            .shadow(color: Palette.cyan.opacity(0.6), radius: 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cyber Salvage Rush")
            .accessibilityAddTraits(.isHeader)

            if scores.bestEndless > 0 {
                Label("BEST \(scores.bestEndless.formatted())", systemImage: "trophy.fill")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(Palette.gold)
            }

            Spacer()

            VStack(spacing: 14) {
                Button("PLAY") { router.screen = .run(.endless) }
                    .buttonStyle(NeonButtonStyle())
                Button {
                    router.screen = .run(.daily)
                } label: {
                    VStack(spacing: 2) {
                        Text("DAILY RUN")
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("new in \(DailySeed.nextReset(after: context.date), style: .timer)")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .buttonStyle(NeonButtonStyle(color: Palette.gold, prominent: false))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainMenuView()
        .environment(AppRouter())
        .environment(ScoreStore())
        .background(Palette.background)
}
