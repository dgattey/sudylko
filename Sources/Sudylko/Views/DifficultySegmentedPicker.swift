import SwiftUI

/// Full-width segmented difficulty control with quick-start icons.
struct DifficultySegmentedPicker: View {
    @Binding var selection: GameDifficulty

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GameDifficulty.allCases) { level in
                segment(for: level)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    private func segment(for level: GameDifficulty) -> some View {
        let theme = PuzzleTheme.forDifficulty(level)
        let isSelected = selection == level
        return Button {
            selection = level
        } label: {
            HStack(spacing: 5) {
                Image(systemName: theme.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.tint)
                Text(level.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.1))
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}
