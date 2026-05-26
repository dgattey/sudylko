import SwiftUI

struct GameTimerBar: View {
    @ObservedObject var timer: PuzzleTimer
    let isPuzzleComplete: Bool

    var body: some View {
        Group {
            if isPuzzleComplete {
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
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 68, alignment: .leading)

            if isPuzzleComplete {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Label(
                    timer.isPaused ? "Resume" : "Pause",
                    systemImage: timer.isPaused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .foregroundStyle(timer.isRunning ? .primary : .secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
