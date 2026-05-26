import SwiftUI

struct DifficultyPill: View {
    let difficulty: GameDifficulty

    private var theme: PuzzleTheme {
        PuzzleTheme.forDifficulty(difficulty)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: theme.systemImage)
                .font(.caption2.weight(.semibold))
            Text(theme.title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(theme.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(theme.tint.opacity(0.14), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(theme.tint.opacity(0.35), lineWidth: 0.5)
        }
    }
}
