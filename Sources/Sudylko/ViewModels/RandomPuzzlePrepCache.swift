import Foundation

/// Background cache of the next random quick-start puzzle per difficulty (no UI state).
@MainActor
final class RandomPuzzlePrepCache {
    struct PreparedRandomPuzzle: Sendable {
        let puzzleSeed: PuzzleSeed
        let template: GeneratedPuzzle
    }

    private var ready: [GameDifficulty: PreparedRandomPuzzle] = [:]
    private var prepTasks: [GameDifficulty: Task<Void, Never>] = [:]
    private var prepTokens: [GameDifficulty: UInt] = [:]

    /// Returns a pre-generated puzzle when available and starts refilling that difficulty.
    func consume(difficulty: GameDifficulty) -> PreparedRandomPuzzle? {
        let entry = ready.removeValue(forKey: difficulty)
        schedulePrepIfNeeded(for: difficulty)
        return entry
    }

    /// Ensures easy, medium, and hard each have a puzzle warming in the background.
    func schedulePrepForAllDifficulties() {
        for difficulty in GameDifficulty.allCases {
            schedulePrepIfNeeded(for: difficulty)
        }
    }

    private func schedulePrepIfNeeded(for difficulty: GameDifficulty) {
        if ready[difficulty] != nil { return }
        if prepTasks[difficulty] != nil { return }

        let token = (prepTokens[difficulty] ?? 0) + 1
        prepTokens[difficulty] = token

        prepTasks[difficulty] = Task {
            let seed = PuzzleSeed.random(difficulty: difficulty)
            let template = await Task.detached(priority: .background) {
                PuzzleGenerator.generate(
                    seed: seed.seedValue,
                    difficulty: difficulty,
                    validateRemovals: true
                )
            }.value

            guard !Task.isCancelled else { return }

            prepTasks[difficulty] = nil
            guard prepTokens[difficulty] == token else { return }
            ready[difficulty] = PreparedRandomPuzzle(puzzleSeed: seed, template: template)
        }
    }
}
