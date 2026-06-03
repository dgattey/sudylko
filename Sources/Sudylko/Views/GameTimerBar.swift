import SwiftUI

struct GameTimerBar: View {
    @ObservedObject var timer: PuzzleTimer
    let isPuzzleEnded: Bool
    let endedLabel: String?
    let endedLabelColor: Color

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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .fixedSize()
    }

    private var timerContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.body)
                .foregroundStyle(.secondary)

            Text(timer.formattedElapsed)
                .font(.callout)
                .monospacedDigit()
                .frame(minWidth: 68, alignment: .leading)

            if isPuzzleEnded, let endedLabel {
                Text(endedLabel)
                    .font(.callout)
                    .foregroundStyle(endedLabelColor)
            } else {
                Label(
                    timer.isPaused ? "Resume" : "Pause",
                    systemImage: timer.isPaused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.titleAndIcon)
                .font(.body)
                .foregroundStyle(timer.isRunning ? .primary : .secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
