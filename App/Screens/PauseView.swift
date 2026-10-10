import SwiftUI

struct PauseView: View {
    let onResume: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(.largeTitle, design: .monospaced).weight(.black))
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                Button("RESUME", action: onResume)
                    .buttonStyle(NeonButtonStyle())
                Button("QUIT TO MENU", action: onQuit)
                    .buttonStyle(NeonButtonStyle(color: Palette.stroke, prominent: false))
            }
            .padding(32)
        }
    }
}
