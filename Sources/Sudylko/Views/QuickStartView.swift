import SwiftUI

struct QuickStartView: View {
    var onEasy: () -> Void
    var onMedium: () -> Void
    var onHard: () -> Void
    var onFromSeed: () -> Void

    @Environment(\.digitFontStyle) private var digitFontStyle
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("Start a new game")
                        .font(digitFontStyle.font(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Pick a difficulty to begin a new puzzle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    QuickStartTile(theme: .easy, action: onEasy)
                    QuickStartTile(theme: .medium, action: onMedium)
                    QuickStartTile(theme: .hard, action: onHard)
                    QuickStartTile(theme: .fromSeed, action: onFromSeed)
                }
                .frame(maxWidth: 420)

                PlayerStatsView()

                AchievementsListView()
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QuickStartTile: View {
    private static let cornerRadius: CGFloat = 14

    let theme: PuzzleTheme
    let action: () -> Void

    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var windowMaterial: WindowBackgroundMaterial {
        WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
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
