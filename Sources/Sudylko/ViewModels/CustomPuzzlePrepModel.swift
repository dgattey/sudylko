import Foundation
import Observation

/// Pre-generates a custom puzzle off the main thread while the seed sheet is open.
@Observable
@MainActor
final class CustomPuzzlePrepModel {
    enum Phase: Equatable {
        case idle
        case invalidInput
        case generating
        case ready
    }

    private(set) var phase: Phase = .idle
    private(set) var readySeed: PuzzleSeed?
    private(set) var readyTemplate: GeneratedPuzzle?

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var generationToken = 0

    var canStart: Bool {
        phase == .ready && readySeed != nil && readyTemplate != nil
    }

    func scheduleUpdate(seedInput: String, difficulty: GameDifficulty) {
        let normalized = PuzzleSeed.normalizedFieldInput(seedInput)
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            applyUpdate(seedInput: normalized, difficulty: difficulty)
        }
    }

    func reset() {
        debounceTask?.cancel()
        generationTask?.cancel()
        debounceTask = nil
        generationTask = nil
        generationToken += 1
        phase = .idle
        readySeed = nil
        readyTemplate = nil
    }

    private func applyUpdate(seedInput: String, difficulty: GameDifficulty) {
        let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let seed = PuzzleSeed.parse(trimmed, difficulty: difficulty) else {
            generationTask?.cancel()
            generationToken += 1
            readySeed = nil
            readyTemplate = nil
            phase = trimmed.isEmpty ? .idle : .invalidInput
            return
        }

        if phase == .ready, readySeed == seed, readyTemplate != nil {
            return
        }

        startGeneration(for: seed)
    }

    private func startGeneration(for seed: PuzzleSeed) {
        generationTask?.cancel()
        generationToken += 1
        let token = generationToken
        readySeed = nil
        readyTemplate = nil
        phase = .generating

        generationTask = Task {
            let template = await Task.detached(priority: .userInitiated) {
                PuzzleGenerator.generate(
                    seed: seed.seedValue,
                    difficulty: seed.difficulty,
                    validateRemovals: true
                )
            }.value

            guard !Task.isCancelled, token == generationToken else { return }

            readySeed = seed
            readyTemplate = template
            phase = .ready
        }
    }
}
