import SwiftUI

/// Full-width segmented difficulty control with quick-start icons.
struct DifficultySegmentedPicker: View {
    @Binding var selection: GameDifficulty

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GameDifficulty.allCases) { level in
                segment(for: level)
            }
        }
        .padding(3)
        .inspectorControlTrack()
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
                    .font(.caption)
                    .foregroundStyle(theme.tint)
                Text(level.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .inspectorSegmentSelection(
            isSelected: isSelected,
            accent: accent,
            colorScheme: colorScheme
        )
    }
}
