import SwiftUI

struct GameTimerBar: View {
    let timer: PuzzleTimer
    let isPuzzleEnded: Bool
    let endedLabel: String?
    let endedLabelColor: Color

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// On iPhone the bar sits between the glass back button and the glass action capsule, which leave it about 120pt
    /// on the smallest phones, so it drops the clock icon and the toggle's title.
    private var isCompact: Bool { horizontalSizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    var body: some View {
        Group {
            if isPuzzleEnded {
                timerContent
            } else {
                Button {
                    guard timer.isRunning else { return }
                    timer.togglePause()
                } label: {
                    timerContent
                }
                .buttonStyle(.plain)
                .macOSTooltip(
                    timer.isPaused ? "Resume the timer (Space)" : "Pause the timer (Space)"
                )
            }
        }
        .padding(.horizontal, isCompact ? 0 : 12)
        .padding(.vertical, 6)
        .fixedSize()
    }

    private var timerContent: some View {
        HStack(spacing: isCompact ? 8 : 14) {
            if !isCompact {
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text(timer.formattedElapsed)
                .font(.callout)
                .monospacedDigit()
                .frame(minWidth: isCompact ? nil : 68, alignment: .leading)

            if isPuzzleEnded, let endedLabel {
                Text(endedLabel)
                    .font(.callout)
                    .foregroundStyle(endedLabelColor)
            } else {
                pauseToggleLabel
                    .font(.body)
                    .foregroundStyle(timer.isRunning ? .primary : .secondary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var pauseToggleLabel: some View {
        let label = Label(
            timer.isPaused ? "Resume" : "Pause",
            systemImage: timer.isPaused ? "play.fill" : "pause.fill"
        )
        if isCompact {
            label.labelStyle(.iconOnly)
        } else {
            label.labelStyle(.titleAndIcon)
        }
    }
}
