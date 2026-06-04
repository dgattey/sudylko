import SwiftUI

struct SaveRowView: View, Equatable {
    private static let archiveControlSide: CGFloat = 22

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
            Group {
                if !slot.isArchived {
                    SidebarArchiveButton(action: onArchiveTap)
                        .opacity(isHovered ? 1 : 0)
                        .allowsHitTesting(isHovered)
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
            .frame(width: Self.archiveControlSide, height: Self.archiveControlSide)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            elapsedLabel
        }
        .onHover { isHovered = $0 }
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
