import SwiftUI

struct PausePlayOverlay: View {
    var accent: AppAccentColor
    var colorScheme: ColorScheme
    var onResume: () -> Void

    var body: some View {
        ZStack {
            AppTheme.tintedBackground(accent: accent, colorScheme: colorScheme)
                .opacity(colorScheme == .dark ? 0.72 : 0.55)

            Button(action: onResume) {
                Image(systemName: "play.fill")
                    .sudylkoSymbolFont(.pausePlayControl)
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(accent.displayColor(for: colorScheme), in: Circle())
                    .shadow(color: accent.displayColor(for: colorScheme).opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .help("Resume")
        }
        .contentShape(Rectangle())
    }
}
