import SalvageCore
import SwiftUI

struct MainMenuView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProfileRepository.self) private var profile
    @Environment(SettingsStore.self) private var settings
    @State private var showingSettings = false
    @State private var showingShop = false

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

            HStack(spacing: 20) {
                if profile.bestEndless > 0 {
                    Label("BEST \(profile.bestEndless.formatted())", systemImage: "trophy.fill")
                }
                CreditsLabel(credits: profile.credits)
            }
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(Palette.gold)

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

                Button {
                    showingShop = true
                } label: {
                    Label("WORKSHOP", systemImage: "wrench.and.screwdriver.fill")
                        .overlay(alignment: .topTrailing) {
                            // Nudge toward the first unlock.
                            if profile.canAffordSomething {
                                Circle().fill(Palette.magenta).frame(width: 10, height: 10).offset(x: 12, y: -4)
                            }
                        }
                }
                .buttonStyle(NeonButtonStyle(color: Palette.stroke, prominent: false))
                .accessibilityHint(profile.canAffordSomething ? "New items affordable" : "")
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
        .sheet(isPresented: $showingShop) {
            ShopView()
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
        .environment(ProfileRepository(container: try! ProfileRepository.makeContainer(inMemory: true)))
        .environment(SettingsStore())
        .background(Palette.background)
}
