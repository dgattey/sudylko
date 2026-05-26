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
    var isLost: Bool
    var isArchived: Bool
    /// True after this save's win has been applied to lifetime stats (prevents replay/reopen double-count).
    var statsCompletionRecorded: Bool
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

    init(
        id: UUID,
        difficulty: GameDifficulty,
        puzzleNumber: Int,
        startedFromCustomSeed: Bool,
        values: [[Int?]],
        notes: [[[Int]]],
        isPencilMode: Bool,
        selectedRow: Int?,
        selectedCol: Int?,
        highlightedDigit: Int?,
        isComplete: Bool,
        isLost: Bool = false,
        isArchived: Bool = false,
        statsCompletionRecorded: Bool = false,
        elapsedSeconds: Double,
        timerPaused: Bool,
        timerRunning: Bool,
        createdAt: Date,
        savedAt: Date
    ) {
        self.id = id
        self.difficulty = difficulty
        self.puzzleNumber = puzzleNumber
        self.startedFromCustomSeed = startedFromCustomSeed
        self.values = values
        self.notes = notes
        self.isPencilMode = isPencilMode
        self.selectedRow = selectedRow
        self.selectedCol = selectedCol
        self.highlightedDigit = highlightedDigit
        self.isComplete = isComplete
        self.isLost = isLost
        self.isArchived = isArchived
        self.statsCompletionRecorded = statsCompletionRecorded
        self.elapsedSeconds = elapsedSeconds
        self.timerPaused = timerPaused
        self.timerRunning = timerRunning
        self.createdAt = createdAt
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        difficulty = try container.decode(GameDifficulty.self, forKey: .difficulty)
        puzzleNumber = try container.decode(Int.self, forKey: .puzzleNumber)
        startedFromCustomSeed = try container.decode(Bool.self, forKey: .startedFromCustomSeed)
        values = try container.decode([[Int?]].self, forKey: .values)
        notes = try container.decode([[[Int]]].self, forKey: .notes)
        isPencilMode = try container.decode(Bool.self, forKey: .isPencilMode)
        selectedRow = try container.decodeIfPresent(Int.self, forKey: .selectedRow)
        selectedCol = try container.decodeIfPresent(Int.self, forKey: .selectedCol)
        highlightedDigit = try container.decodeIfPresent(Int.self, forKey: .highlightedDigit)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        isLost = try container.decodeIfPresent(Bool.self, forKey: .isLost) ?? false
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        statsCompletionRecorded = try container.decodeIfPresent(Bool.self, forKey: .statsCompletionRecorded) ?? false
        elapsedSeconds = try container.decode(Double.self, forKey: .elapsedSeconds)
        timerPaused = try container.decode(Bool.self, forKey: .timerPaused)
        timerRunning = try container.decode(Bool.self, forKey: .timerRunning)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
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
        let existing = GameSaveStore.load(id: id)
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
            isLost: game.isLost,
            isArchived: existing?.isArchived ?? false,
            statsCompletionRecorded: existing?.statsCompletionRecorded ?? false,
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
    let elapsedSeconds: Double
    let isComplete: Bool
    let isArchived: Bool
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

    @discardableResult
    static func save(_ state: SavedGameState) -> Bool {
        var stateToWrite = state
        if let existing = load(id: state.id) {
            stateToWrite.createdAt = existing.createdAt
        }
        guard let data = try? JSONEncoder().encode(stateToWrite) else { return false }
        UserDefaults.standard.set(data, forKey: storageKey(for: stateToWrite.id))
        var ids = loadIndex()
        if !ids.contains(stateToWrite.id) {
            ids.append(stateToWrite.id)
        }
        saveIndex(ids)
        return true
    }

    static func postSavesDidChange(_ reason: SavesChangeReason? = nil) {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .savesDidChange, object: reason)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .savesDidChange, object: reason)
            }
        }
    }

    static func load(id: UUID) -> SavedGameState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: id)),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            return nil
        }
        return state
    }

    static func archive(id: UUID) {
        guard var state = load(id: id) else { return }
        state.isArchived = true
        save(state)
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
        postSavesDidChange(.deleteAll)
    }

    static func summaries() -> [SaveSlotSummary] {
        loadIndex().compactMap { id -> SaveSlotSummary? in
            guard let state = load(id: id) else { return nil }
            return SaveSlotSummary(
                id: id,
                puzzleSeed: state.puzzleSeed,
                elapsedSeconds: state.elapsedSeconds,
                isComplete: state.isComplete,
                isArchived: state.isArchived,
                createdAt: state.createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    #if DEBUG
    /// Inserts a finished save for sidebar and end-state testing.
    @discardableResult
    static func debugSeedCompletedGame() -> UUID {
        let puzzleSeed = PuzzleSeed(number: 4242, difficulty: .medium)
        let generated = PuzzleGenerator.generate(
            seed: puzzleSeed.seedValue,
            difficulty: puzzleSeed.difficulty
        )
        let values = generated.solution.map { row in row.map { Optional($0) } }
        let emptyNotes = Array(repeating: Array(repeating: [Int](), count: 9), count: 9)
        let now = Date()
        let id = UUID()
        let state = SavedGameState(
            id: id,
            difficulty: puzzleSeed.difficulty,
            puzzleNumber: puzzleSeed.number,
            startedFromCustomSeed: false,
            values: values,
            notes: emptyNotes,
            isPencilMode: false,
            selectedRow: nil,
            selectedCol: nil,
            highlightedDigit: nil,
            isComplete: true,
            isLost: false,
            statsCompletionRecorded: true,
            elapsedSeconds: 422,
            timerPaused: false,
            timerRunning: false,
            createdAt: now,
            savedAt: now
        )
        guard save(state) else {
            assertionFailure("debugSeedCompletedGame: failed to encode or persist save")
            return id
        }
        postSavesDidChange()
        return id
    }
    #endif
}
