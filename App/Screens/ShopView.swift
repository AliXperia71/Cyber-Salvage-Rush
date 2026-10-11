import SalvageCore
import SwiftUI

/// Workshop: spend credits on themes, drones, and Endless-only upgrades.
struct ShopView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case themes = "Themes"
        case drones = "Drones"
        case upgrades = "Upgrades"
        var id: Self { self }
    }

    @Environment(ProfileRepository.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .themes
    @State private var purchased = 0
    @State private var declined = 0

    private let catalog = EconomyConfig.standard.catalog

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Section", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .themes: grid(of: .theme)
                    case .drones: grid(of: .drone)
                    case .upgrades: upgrades
                    }
                }
                .padding(16)
            }
            .background(Palette.background)
            .navigationTitle("Workshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CreditsLabel(credits: profile.credits)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(Palette.gold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.success, trigger: purchased)
        .sensoryFeedback(.error, trigger: declined)
    }

    // MARK: - Cosmetics

    private func grid(of kind: Cosmetic.Kind) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(catalog.filter { $0.kind == kind }) { item in
                CosmeticCard(item: item, state: state(of: item), canAfford: profile.credits >= item.price,
                             equippedThemeID: profile.equippedThemeID) {
                    act(on: item)
                }
            }
        }
    }

    private func state(of item: Cosmetic) -> CosmeticCard.State {
        if item.id == profile.equippedThemeID || item.id == profile.equippedDroneID { return .equipped }
        return profile.owned.contains(item.id) ? .owned : .locked
    }

    private func act(on item: Cosmetic) {
        do {
            if profile.owned.contains(item.id) {
                try profile.equip(item.id)
            } else {
                try profile.purchase(item)
                purchased += 1
            }
        } catch {
            declined += 1
        }
    }

    // MARK: - Upgrades

    private var upgrades: some View {
        VStack(spacing: 12) {
            ForEach(Upgrade.allCases, id: \.self) { upgrade in
                UpgradeRow(upgrade: upgrade, level: profile.upgrades[upgrade], credits: profile.credits) {
                    do {
                        try profile.buyUpgrade(upgrade)
                        purchased += 1
                    } catch {
                        declined += 1
                    }
                }
            }
            Text("Upgrades apply in Endless only. Daily and challenge runs use fixed rules.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.stroke)
                .multilineTextAlignment(.center)
        }
    }
}

struct CreditsLabel: View {
    let credits: Int

    var body: some View {
        Label(credits.formatted(), systemImage: "circle.hexagongrid.fill")
            .labelStyle(.titleAndIcon) // toolbars default to icon-only
            .accessibilityLabel("\(credits) credits")
    }
}

private struct CosmeticCard: View {
    enum State { case locked, owned, equipped }

    let item: Cosmetic
    let state: State
    let canAfford: Bool
    let equippedThemeID: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            preview
                .frame(height: 64)
            Text(item.name.uppercased())
                .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button(action: action) {
                Group {
                    switch state {
                    case .equipped: Text("EQUIPPED")
                    case .owned: Text("EQUIP")
                    case .locked: CreditsLabel(credits: item.price)
                    }
                }
                .font(.system(.caption, design: .monospaced).weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 36)
                .foregroundStyle(state == .equipped ? Palette.background : buttonColor)
                .background(state == .equipped ? Palette.cyan : buttonColor.opacity(0.1), in: .rect(cornerRadius: 10))
            }
            .disabled(state == .equipped)
        }
        .padding(12)
        .background(Palette.panel, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(state == .equipped ? Palette.cyan : Palette.stroke.opacity(0.5), lineWidth: state == .equipped ? 2 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if state != .equipped { action() } }
    }

    private var buttonColor: Color {
        state == .locked && !canAfford ? Palette.stroke : Palette.gold
    }

    private var accessibilityValue: String {
        switch state {
        case .equipped: "Equipped"
        case .owned: "Owned"
        case .locked: canAfford ? "\(item.price) credits" : "\(item.price) credits, not enough credits"
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .theme:
            let theme = Theme.with(id: item.id)
            HStack(spacing: 6) {
                ForEach(ItemKind.allCases, id: \.self) { kind in
                    Image(systemName: kind.symbolName)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(uiColor: theme.background))
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: theme.color(for: kind)), in: .rect(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: theme.background), in: .rect(cornerRadius: 10))
        case .drone:
            // Drones take their colors from the equipped theme, so preview them that way.
            Image(uiImage: ProceduralTextureFactory(theme: Theme.with(id: equippedThemeID)).droneImage(item.id, size: 64))
        }
    }
}

private struct UpgradeRow: View {
    let upgrade: Upgrade
    let level: Int
    let credits: Int
    let action: () -> Void

    private var maxLevel: Int { Economy.maxLevel(of: upgrade) }
    private var cost: Int? { Economy.nextLevelCost(of: upgrade, currentLevel: level) }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(upgrade.title)
                    .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                    .foregroundStyle(Palette.text)
                Text(upgrade.effect)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.stroke)
                HStack(spacing: 4) {
                    ForEach(0..<maxLevel, id: \.self) { index in
                        Capsule()
                            .fill(index < level ? Palette.cyan : Palette.stroke.opacity(0.3))
                            .frame(width: 18, height: 6)
                    }
                }
            }
            Spacer(minLength: 8)
            Button(action: action) {
                Group {
                    if let cost { CreditsLabel(credits: cost) } else { Text("MAX") }
                }
                .font(.system(.caption, design: .monospaced).weight(.heavy))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .foregroundStyle(affordable ? Palette.gold : Palette.stroke)
                .background((affordable ? Palette.gold : Palette.stroke).opacity(0.1), in: .rect(cornerRadius: 10))
            }
            .disabled(cost == nil)
        }
        .padding(14)
        .background(Palette.panel, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(upgrade.title)
        .accessibilityValue("Level \(level) of \(maxLevel). \(upgrade.effect). " + (cost.map { "Next level \($0) credits" } ?? "Maxed"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if cost != nil { action() } }
    }

    private var affordable: Bool { cost.map { credits >= $0 } ?? false }
}

private extension Upgrade {
    var title: String {
        switch self {
        case .bufferExpansion: "Buffer Expansion"
        case .fuseDampener: "Fuse Dampener"
        case .comboShield: "Combo Shield"
        }
    }

    var effect: String {
        switch self {
        case .bufferExpansion: "+1 tray slot per level"
        case .fuseDampener: "Hazard fuses last 5% longer per level"
        case .comboShield: "Each level forgives one wrong bin per run"
        }
    }
}

#Preview {
    ShopView()
        .environment(ProfileRepository(container: try! ProfileRepository.makeContainer(inMemory: true)))
}
