import SwiftUI

struct SaveRowView: View {
    let slot: SaveSlotSummary
    let displayTime: String
    var onArchiveTap: () -> Void

    @Environment(\.digitFontStyle) private var digitFontStyle
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(slot.gameTitle)
                    .font(digitFontStyle.font(size: 15, weight: .semibold))
                DifficultyPill(difficulty: slot.puzzleSeed.difficulty)
            }
            Spacer(minLength: 4)
            if isHovered {
                SidebarArchiveButton(action: onArchiveTap)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Text(displayTime)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
