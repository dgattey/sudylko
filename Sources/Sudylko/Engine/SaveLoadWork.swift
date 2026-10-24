import Foundation

/// All save-file disk I/O (load, encode, UserDefaults), serialized on one queue so every read sees
/// the writes requested before it and writes never interleave their index updates. Callers on the
/// main actor snapshot `SavedGameState` first.
enum SaveLoadWork: Sendable {
    private static let ioQueue = DispatchQueue(label: "com.sudylko.save-io", qos: .utility)

    struct RestorePayload: Sendable {
        let state: SavedGameState
        let template: GeneratedPuzzle
    }

    struct NewGamePayload: Sendable {
        let template: GeneratedPuzzle
        let puzzleSeed: PuzzleSeed
        let startedFromCustomSeed: Bool
    }

    // MARK: - Writes

    static func enqueueSave(_ state: SavedGameState) {
        ioQueue.async {
            GameSaveStore.save(state)
        }
    }

    static func archive(id: UUID) {
        ioQueue.async {
            GameSaveStore.archive(id: id)
        }
    }

    static func deleteAll() {
        ioQueue.async {
            GameSaveStore.deleteAll()
        }
    }

    static func delete(id: UUID) {
        ioQueue.async {
            GameSaveStore.delete(id: id)
        }
    }

    static func deleteArchived() {
        ioQueue.async {
            GameSaveStore.deleteArchived()
        }
    }

    #if DEBUG
    static func debugSeedCompletedGame() {
        ioQueue.async {
            GameSaveStore.debugSeedCompletedGame()
        }
    }
    #endif

    // MARK: - Reads

    static func restorePayload(saveID: UUID) async -> RestorePayload? {
        await afterPendingWrites {
            guard let state = GameSaveStore.load(id: saveID),
                  let template = puzzleTemplate(for: state) else { return nil }
            return RestorePayload(state: state, template: template)
        }
    }

    static func load(id: UUID) async -> SavedGameState? {
        await afterPendingWrites { GameSaveStore.load(id: id) }
    }

    static func summaries() async -> [SaveSlotSummary] {
        await afterPendingWrites { GameSaveStore.summaries() }
    }

    private static func afterPendingWrites<T: Sendable>(_ read: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            ioQueue.async {
                continuation.resume(returning: read())
            }
        }
    }

    static func newGamePayload(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool
    ) -> NewGamePayload {
        let template = PuzzleGenerator.generate(
            seed: puzzleSeed.seedValue,
            difficulty: puzzleSeed.difficulty,
            validateRemovals: true
        )
        return NewGamePayload(
            template: template,
            puzzleSeed: puzzleSeed,
            startedFromCustomSeed: startedFromCustomSeed
        )
    }

    private static func puzzleTemplate(for state: SavedGameState) -> GeneratedPuzzle? {
        guard state.givenCells.isEmpty == false else { return nil }
        return GeneratedPuzzle(
            solution: state.storedSolution,
            puzzle: state.initialPuzzleFromGivens(),
            givens: Set(state.givenCells.map { CellIndex(row: $0.row, col: $0.col) })
        )
    }
}
