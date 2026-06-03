import Combine
import Foundation

@MainActor
final class PuzzleTimer: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isPaused = false
    @Published private(set) var isRunning = false

    private var accumulated: TimeInterval = 0
    private var segmentStart: Date?
    private var ticker: Timer?

    var formattedElapsed: String {
        Self.format(elapsed)
    }

    func start() {
        reset()
        isRunning = true
        isPaused = false
        segmentStart = Date()
        startTicker()
        refreshElapsed()
    }

    func reset() {
        stopTicker()
        accumulated = 0
        segmentStart = nil
        elapsed = 0
        isPaused = false
        isRunning = false
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        commitSegment()
        isPaused = true
        stopTicker()
        elapsed = accumulated
    }

    func resume() {
        guard isRunning else { return }
        guard isPaused else { return }
        isPaused = false
        segmentStart = Date()
        startTicker()
        refreshElapsed()
    }

    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    func finish() {
        if isRunning && !isPaused {
            commitSegment()
        }
        stopTicker()
        isPaused = true
        isRunning = false
        elapsed = accumulated
    }

    func restore(from state: SavedGameState) {
        stopTicker()
        accumulated = state.elapsedSeconds
        elapsed = state.elapsedSeconds
        isPaused = state.timerPaused
        isRunning = state.timerRunning

        if state.outcome.isEnded {
            finish()
            return
        }

        if isRunning && !isPaused {
            segmentStart = Date()
            startTicker()
            refreshElapsed()
        }
    }

    private func commitSegment() {
        if let segmentStart {
            accumulated += Date().timeIntervalSince(segmentStart)
        }
        self.segmentStart = nil
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshElapsed()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func refreshElapsed() {
        if let segmentStart {
            elapsed = accumulated + Date().timeIntervalSince(segmentStart)
        } else {
            elapsed = accumulated
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
