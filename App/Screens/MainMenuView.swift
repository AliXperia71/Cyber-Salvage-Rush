import SalvageCore
import SwiftUI

struct MainMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ScoreStore.self) private var scores
    @Environment(SettingsStore.self) private var settings
    @State private var showingSettings = false

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
                Button("PLAY") { router.screen = .run(settings.tutorialCompleted ? .endless : .tutorial) }
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
        .overlay(alignment: .topTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.stroke)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            .padding(.trailing, 12)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .presentationDetents([.medium])
        }
    }
}

#Preview {
    MainMenuView()
        .environment(AppRouter())
        .environment(ScoreStore())
        .environment(SettingsStore())
        .background(Palette.background)
}
