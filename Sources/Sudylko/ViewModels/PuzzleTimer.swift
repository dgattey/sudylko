import Foundation
import Observation

@Observable
@MainActor
final class PuzzleTimer {
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPaused = false
    private(set) var isRunning = false

    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?

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

    /// Ticks only while a segment runs; `stopTicker` cancels the sleep.
    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while (try? await Task.sleep(for: .seconds(1))) != nil {
                guard let self else { return }
                self.refreshElapsed()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
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
