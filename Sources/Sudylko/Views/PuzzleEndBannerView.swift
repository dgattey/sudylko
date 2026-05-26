import SwiftUI

struct PuzzleEndBannerView: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let formattedElapsed: String
    let buttonTitle: String
    let buttonTint: Color
    let onButton: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .symbolRenderingMode(.palette)
                .foregroundStyle(iconColor, .primary.opacity(0.15))
            Text(title)
                .font(.title2.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text("Time: \(formattedElapsed)")
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: onButton)
                .buttonStyle(.borderedProminent)
                .tint(buttonTint)
        }
        .padding(28)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .compositingGroup()
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.42 : 0.18),
            radius: 24,
            y: 10
        )
    }
}
