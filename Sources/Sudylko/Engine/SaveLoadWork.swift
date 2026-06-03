import Foundation

/// All save-file disk I/O (load, encode, UserDefaults). Callers on the main actor snapshot
/// `SavedGameState` first, then invoke these from a detached task or `enqueueSave`.
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

    // MARK: - Writes (serialized background queue)

    static func enqueueSave(_ state: SavedGameState) {
        ioQueue.async {
            GameSaveStore.save(state)
        }
    }

    // MARK: - Reads (call from `Task.detached` only)

    static func restorePayload(saveID: UUID) -> RestorePayload? {
        guard let state = GameSaveStore.load(id: saveID),
              let template = puzzleTemplate(for: state) else { return nil }
        return RestorePayload(state: state, template: template)
    }

    static func load(id: UUID) -> SavedGameState? {
        GameSaveStore.load(id: id)
    }

    static func summaries() -> [SaveSlotSummary] {
        GameSaveStore.summaries()
    }

    static func archive(id: UUID) {
        GameSaveStore.archive(id: id)
    }

    static func deleteAll() {
        GameSaveStore.deleteAll()
    }

    #if DEBUG
    @discardableResult
    static func debugSeedCompletedGame() -> UUID {
        GameSaveStore.debugSeedCompletedGame()
    }
    #endif

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
