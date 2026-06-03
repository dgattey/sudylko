import SwiftUI

struct SaveRowView: View, Equatable {
    let slot: SaveSlotSummary
    let staticElapsed: String
    var showsLiveTimer: Bool = false
    var liveTimer: PuzzleTimer?
    var onArchiveTap: () -> Void

    @State private var isHovered = false

    static func == (lhs: SaveRowView, rhs: SaveRowView) -> Bool {
        lhs.slot == rhs.slot
            && lhs.staticElapsed == rhs.staticElapsed
            && lhs.showsLiveTimer == rhs.showsLiveTimer
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(slot.gameTitle)
                    .font(.subheadline)
                DifficultyPill(difficulty: slot.puzzleSeed.difficulty)
            }
            Spacer(minLength: 4)
            SidebarArchiveButton(action: onArchiveTap)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
            elapsedLabel
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var elapsedLabel: some View {
        if showsLiveTimer, let liveTimer {
            SaveRowLiveElapsedLabel(timer: liveTimer)
        } else {
            Text(staticElapsed)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

/// Updates once per second without observing `PuzzleTimer` (avoids rebuilding the games list).
private struct SaveRowLiveElapsedLabel: View {
    let timer: PuzzleTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(timer.formattedElapsed)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
