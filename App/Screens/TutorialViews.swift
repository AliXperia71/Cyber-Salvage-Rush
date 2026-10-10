import SalvageCore
import SwiftUI

/// Tutorial HUD: a 4-word goal plus a 2–3 word hint for the waiting item. No score or overload to read.
struct TutorialHUDView: View {
    let hint: ItemKind?
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("TRAINING")
                    .font(.system(.caption, design: .monospaced).weight(.heavy))
                    .foregroundStyle(Palette.stroke)
                Spacer()
                Button("SKIP", action: onSkip)
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(Palette.text)
                    .frame(minWidth: 64, minHeight: 44)
                    .background(Palette.panel, in: .capsule)
                    .accessibilityHint("Skips training and starts a run")
            }

            Text("DRAG TO MATCHING BIN")
                .font(.system(.title3, design: .monospaced).weight(.black))
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            if let hint {
                Label(hint.tutorialCaption, systemImage: hint.symbolName)
                    .font(.system(.headline, design: .monospaced).weight(.bold))
                    .foregroundStyle(hint.paletteColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(hint.paletteColor.opacity(0.12), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
                    .id(hint)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(duration: 0.3), value: hint)
    }
}

/// Brief confirmation, then straight into the first real run.
struct TutorialCompleteView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.cyan)
                Text("SYSTEMS ONLINE")
                    .font(.system(.title, design: .monospaced).weight(.black))
                    .foregroundStyle(Palette.text)
                Text("Don't let it overload")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Palette.stroke)
            }
            .accessibilityElement(children: .combine)
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            onContinue()
        }
    }
}

extension ItemKind {
    var tutorialCaption: String {
        switch self {
        case .standard: "SCRAP → RECYCLE"
        case .valuable: "VALUABLES → VAULT"
        case .hazardous: "HAZARDS → HAZMAT"
        }
    }

    @MainActor var paletteColor: Color {
        switch self {
        case .standard: Palette.cyan
        case .valuable: Palette.gold
        case .hazardous: Palette.magenta
        }
    }
}
