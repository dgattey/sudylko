import Foundation

struct SavedGameState: Codable, Equatable, Identifiable, Sendable {
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
    var outcome: PuzzleOutcome
    /// Wrong guesses this puzzle (persisted for stats/achievements after reload).
    var mistakesThisPuzzle: Int
    var isArchived: Bool
    /// True after this save's win has been applied to lifetime stats (prevents replay/revisit double-count).
    var statsCompletionRecorded: Bool
    var elapsedSeconds: Double
    var timerPaused: Bool
    var timerRunning: Bool
    var createdAt: Date
    var savedAt: Date
    /// Cached answer grid — required for restore (no runtime generation).
    var storedSolution: [[Int]]
    /// Original clue cells for this puzzle (same order as generator givens).
    var givenCells: [CellIndex]

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
        outcome: PuzzleOutcome,
        mistakesThisPuzzle: Int = 0,
        isArchived: Bool = false,
        statsCompletionRecorded: Bool = false,
        elapsedSeconds: Double,
        timerPaused: Bool,
        timerRunning: Bool,
        createdAt: Date,
        savedAt: Date,
        storedSolution: [[Int]],
        givenCells: [CellIndex]
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
        self.outcome = outcome
        self.mistakesThisPuzzle = mistakesThisPuzzle
        self.isArchived = isArchived
        self.statsCompletionRecorded = statsCompletionRecorded
        self.elapsedSeconds = elapsedSeconds
        self.timerPaused = timerPaused
        self.timerRunning = timerRunning
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.storedSolution = storedSolution
        self.givenCells = givenCells
    }

    /// Starting clue layout from persisted givens.
    func initialPuzzleFromGivens() -> [[Int?]] {
        var puzzle = Array(repeating: Array(repeating: nil as Int?, count: 9), count: 9)
        for cell in givenCells {
            puzzle[cell.row][cell.col] = storedSolution[cell.row][cell.col]
        }
        return puzzle
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
        outcome = try container.decode(PuzzleOutcome.self, forKey: .outcome)
        mistakesThisPuzzle = try container.decodeIfPresent(Int.self, forKey: .mistakesThisPuzzle) ?? 0
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        statsCompletionRecorded = try container.decodeIfPresent(Bool.self, forKey: .statsCompletionRecorded) ?? false
        elapsedSeconds = try container.decode(Double.self, forKey: .elapsedSeconds)
        timerPaused = try container.decode(Bool.self, forKey: .timerPaused)
        timerRunning = try container.decode(Bool.self, forKey: .timerRunning)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        storedSolution = try container.decode([[Int]].self, forKey: .storedSolution)
        givenCells = try container.decode([CellIndex].self, forKey: .givenCells)
        guard !givenCells.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Save missing puzzle givens.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(puzzleNumber, forKey: .puzzleNumber)
        try container.encode(startedFromCustomSeed, forKey: .startedFromCustomSeed)
        try container.encode(values, forKey: .values)
        try container.encode(notes, forKey: .notes)
        try container.encode(isPencilMode, forKey: .isPencilMode)
        try container.encodeIfPresent(selectedRow, forKey: .selectedRow)
        try container.encodeIfPresent(selectedCol, forKey: .selectedCol)
        try container.encodeIfPresent(highlightedDigit, forKey: .highlightedDigit)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(mistakesThisPuzzle, forKey: .mistakesThisPuzzle)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(statsCompletionRecorded, forKey: .statsCompletionRecorded)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encode(timerPaused, forKey: .timerPaused)
        try container.encode(timerRunning, forKey: .timerRunning)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(storedSolution, forKey: .storedSolution)
        try container.encode(givenCells, forKey: .givenCells)
    }

    private enum CodingKeys: String, CodingKey {
        case id, difficulty, puzzleNumber, startedFromCustomSeed, values, notes
        case isPencilMode, selectedRow, selectedCol, highlightedDigit
        case outcome, mistakesThisPuzzle
        case isArchived, statsCompletionRecorded
        case elapsedSeconds, timerPaused, timerRunning, createdAt, savedAt
        case storedSolution, givenCells
    }

    /// Snapshot written to disk: puzzle progress, session chrome, and timer metadata.
    @MainActor
    static func from(
        id: UUID,
        game: GameViewModel,
        timer: PuzzleTimer,
        metadata: SavePersistMetadata,
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
            outcome: game.outcome,
            mistakesThisPuzzle: game.mistakesThisPuzzle,
            isArchived: metadata.isArchived,
            statsCompletionRecorded: metadata.statsCompletionRecorded,
            elapsedSeconds: timer.elapsed,
            timerPaused: timer.isPaused,
            timerRunning: timer.isRunning,
            createdAt: metadata.createdAt,
            savedAt: date,
            storedSolution: game.solution,
            givenCells: game.givens.sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
        )
    }
}

/// Metadata needed when persisting without re-reading the full save from disk.
struct SavePersistMetadata: Equatable, Sendable {
    var createdAt: Date
    var isArchived: Bool
    var statsCompletionRecorded: Bool

    init(createdAt: Date, isArchived: Bool, statsCompletionRecorded: Bool) {
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.statsCompletionRecorded = statsCompletionRecorded
    }

    init(state: SavedGameState) {
        createdAt = state.createdAt
        isArchived = state.isArchived
        statsCompletionRecorded = state.statsCompletionRecorded
    }
}

struct SaveSlotSummary: Identifiable, Equatable {
    let id: UUID
    let puzzleSeed: PuzzleSeed
    let elapsedSeconds: Double
    let outcome: PuzzleOutcome
    let isArchived: Bool
    let createdAt: Date

    var gameTitle: String {
        "Game \(puzzleSeed.gameNumberLabel)"
    }
}

enum GameSaveStore {
    private static let indexKey = "savedGameIDs"
    private static let cacheLock = NSLock()
    private static var decodedCache: [UUID: SavedGameState] = [:]

    private static func storageKey(for id: UUID) -> String {
        "savedGame.\(id.uuidString)"
    }

    private static func cacheRead(id: UUID) -> SavedGameState? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return decodedCache[id]
    }

    private static func cacheWrite(_ state: SavedGameState) {
        cacheLock.lock()
        decodedCache[state.id] = state
        cacheLock.unlock()
    }

    private static func cacheRemove(id: UUID) {
        cacheLock.lock()
        decodedCache.removeValue(forKey: id)
        cacheLock.unlock()
    }

    private static func cacheClear() {
        cacheLock.lock()
        decodedCache.removeAll()
        cacheLock.unlock()
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
        guard let data = try? JSONEncoder().encode(state) else { return false }
        UserDefaults.standard.set(data, forKey: storageKey(for: state.id))
        var ids = loadIndex()
        if !ids.contains(state.id) {
            ids.append(state.id)
        }
        saveIndex(ids)
        cacheWrite(state)
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
        if let cached = cacheRead(id: id) {
            return cached
        }
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: id)),
              let state = try? JSONDecoder().decode(SavedGameState.self, from: data) else {
            return nil
        }
        cacheWrite(state)
        return state
    }

    static func archive(id: UUID) {
        guard var state = load(id: id) else { return }
        state.isArchived = true
        save(state)
    }

    static func deleteAll() {
        for id in loadIndex() {
            UserDefaults.standard.removeObject(forKey: storageKey(for: id))
        }
        UserDefaults.standard.removeObject(forKey: indexKey)
        cacheClear()
        postSavesDidChange(.deleteAll)
    }

    static func summaries() -> [SaveSlotSummary] {
        loadIndex().compactMap { id -> SaveSlotSummary? in
            guard let state = load(id: id) else { return nil }
            return SaveSlotSummary(
                id: id,
                puzzleSeed: state.puzzleSeed,
                elapsedSeconds: state.elapsedSeconds,
                outcome: state.outcome,
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
            difficulty: puzzleSeed.difficulty,
            validateRemovals: true
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
            outcome: .won,
            statsCompletionRecorded: true,
            elapsedSeconds: 422,
            timerPaused: false,
            timerRunning: false,
            createdAt: now,
            savedAt: now,
            storedSolution: generated.solution,
            givenCells: generated.givens.sorted { $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row }
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
