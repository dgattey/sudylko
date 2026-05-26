import SwiftUI

// MARK: - Difficulty tiles

struct QuickStartTile: View {
    private static let cornerRadius: CGFloat = 14

    let theme: PuzzleTheme
    let action: () -> Void

    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.isWindowFullscreen) private var isWindowFullscreen
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var windowMaterial: WindowBackgroundMaterial {
        let stored = WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
        return stored.effective(whenFullscreen: isWindowFullscreen)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: theme.systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.tint)
                Text(theme.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(theme.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding(16)
            .glassPanel(
                accent: accent,
                colorScheme: colorScheme,
                material: windowMaterial,
                cornerRadius: Self.cornerRadius
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHovered ? accent.selectionBorder(for: colorScheme) : accent.displayColor(for: colorScheme).opacity(0.14),
                        lineWidth: isHovered && accent.prefersStrongSelectionBorder ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .sudylkoFocusSuppressed()
        .onHover { isHovered = $0 }
    }
}
