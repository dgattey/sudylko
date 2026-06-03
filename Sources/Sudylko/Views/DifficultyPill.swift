import SwiftUI

struct DifficultyPill: View {
    let difficulty: GameDifficulty

    private var theme: PuzzleTheme {
        PuzzleTheme.forDifficulty(difficulty)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: theme.systemImage)
                .font(.caption)
            Text(theme.title)
                .font(.caption)
        }
        .foregroundStyle(theme.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.tint.opacity(InspectorSurface.chipFillOpacity), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(theme.tint.opacity(InspectorSurface.chipBorderOpacity), lineWidth: 0.5)
        }
    }
}
