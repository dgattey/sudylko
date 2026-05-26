import Foundation

struct SavedGameState: Codable, Equatable, Identifiable {
    var id: UUID
    var difficulty: GameDifficulty
    var puzzleNumber: Int
    var startedFromCustomSeed: Bool
    var values: [[Int?]]
    var notes: [[[Int]]]
    var isPencilMode: Bool
    var selectedRow: Int?
    var selectedCol: Int?
    var highlightedDigit: Int?
    var isComplete: Bool
    var elapsedSeconds: Double
    var timerPaused: Bool
    var timerRunning: Bool
    var createdAt: Date
    var savedAt: Date

    var puzzleSeed: PuzzleSeed {
        PuzzleSeed(number: puzzleNumber, difficulty: difficulty)
    }

    var selected: CellIndex? {
        guard let selectedRow, let selectedCol else { return nil }
        return CellIndex(row: selectedRow, col: selectedCol)
    }

    @MainActor
    static func from(
        id: UUID,
        game: GameViewModel,
        timer: PuzzleTimer,
        createdAt: Date,
        at date: Date = Date()
    ) -> SavedGameState {
        let notePayload = game.notes.map { row in
            row.map { Array($0).sorted() }
        }
        return SavedGameState(
            id: id,
            difficulty: game.difficulty,
            puzzleNumber: game.puzzleSeed.number,
            startedFromCustomSeed: game.startedFromCustomSeed,
            values: game.values,
            notes: notePayload,
            isPencilMode: game.isPencilMode,
            selectedRow: game.selected?.row,
            selectedCol: game.selected?.col,
            highlightedDigit: game.highlightedDigit,
            isComplete: game.isComplete,
            elapsedSeconds: timer.elapsed,
            timerPaused: timer.isPaused,
            timerRunning: timer.isRunning,
            createdAt: createdAt,
            savedAt: date
        )
    }
}

struct SaveSlotSummary: Identifiable, Equatable {
    let id: UUID
    let puzzleSeed: PuzzleSeed
    let startedFromCustomSeed: Bool
    let elapsedSeconds: Double
    let isComplete: Bool
    let createdAt: Date

    var gameTitle: String {
        "Game \(puzzleSeed.gameNumberLabel)"
    }
}

enum GameSaveStore {
    private static let indexKey = "savedGameIDs"

    private static func storageKey(for id: UUID) -> String {
        "savedGame.\(id.uuidString)"
    }

    private static func loadIndex() -> [UUID] {
        guard let strings = UserDefaults.standard.stringArray(forKey: indexKey) else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }

    private static func saveIndex(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: indexKey)
    }

    static func save(_ state: SavedGameState) {
        var stateToWrite = state
        if let existing = load(id: state.id) {
            stateToWrite.createdAt = existing.createdAt
        }
        guard let data = try? JSONEncoder().encode(stateToWrite) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(for: stateToWrite.id))
        var ids = loadIndex()
        if !ids.contains(stateToWrite.id) {
            ids.append(stateToWrite.id)
        }
        saveIndex(ids)
    }

    static func load(id: UUID) -> SavedGameState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: id)),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            return nil
        }
        return state
    }

    static func delete(id: UUID) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: id))
        var ids = loadIndex()
        ids.removeAll { $0 == id }
        saveIndex(ids)
    }

    static func deleteAll() {
        for id in loadIndex() {
            UserDefaults.standard.removeObject(forKey: storageKey(for: id))
        }
        UserDefaults.standard.removeObject(forKey: indexKey)
        NotificationCenter.default.post(name: .savesDidChange, object: nil)
    }

    static func summaries() -> [SaveSlotSummary] {
        loadIndex().compactMap { id -> SaveSlotSummary? in
            guard let state = load(id: id) else { return nil }
            return SaveSlotSummary(
                id: id,
                puzzleSeed: state.puzzleSeed,
                startedFromCustomSeed: state.startedFromCustomSeed,
                elapsedSeconds: state.elapsedSeconds,
                isComplete: state.isComplete,
                createdAt: state.createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }
}
