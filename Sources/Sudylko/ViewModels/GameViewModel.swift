import Combine
import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var puzzleSeed: PuzzleSeed
    @Published var difficulty: GameDifficulty
    @Published private(set) var startedFromCustomSeed = false
    @Published private(set) var solution: [[Int]]
    @Published private(set) var givens: Set<CellIndex>
    @Published var values: [[Int?]]
    @Published var notes: [[Set<Int>]]
    @Published var isPencilMode = false
    @Published var selected: CellIndex?
    @Published var highlightedDigit: Int?
    @Published var pulseRows: Set<Int> = []
    @Published var pulseCols: Set<Int> = []
    @Published var pulseBoxes: Set<Int> = []
    @Published private(set) var isComplete = false
    @Published var mistakeCells: Set<CellIndex> = []
    @Published private(set) var mistakesThisPuzzle = 0
    @Published private(set) var usedNotesThisPuzzle = false
    var revealMistakesImmediately = false
    /// When false, board and keyboard input are ignored (paused, unfocused, or complete).
    var isInputEnabled = true
    /// Bumped when puzzle state changes so the UI can persist saves.
    @Published private(set) var saveRevision = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var canDelete = false

    private var undoStack: [CellEditSnapshot] = []
    private var redoStack: [CellEditSnapshot] = []
    private var completedRows: Set<Int> = []
    private var completedCols: Set<Int> = []
    private var completedBoxes: Set<Int> = []

    init(puzzleSeed: PuzzleSeed, startedFromCustomSeed: Bool = false) {
        self.puzzleSeed = puzzleSeed
        self.difficulty = puzzleSeed.difficulty
        self.startedFromCustomSeed = startedFromCustomSeed
        solution = []
        givens = []
        values = []
        notes = Self.emptyNotes()
        let generated = PuzzleGenerator.generate(seed: puzzleSeed.seedValue, difficulty: puzzleSeed.difficulty)
        applyGenerated(generated)
    }

    func replayCurrentPuzzle() {
        start(puzzleSeed: puzzleSeed, startedFromCustomSeed: startedFromCustomSeed)
    }

    func start(puzzleSeed: PuzzleSeed, startedFromCustomSeed: Bool = false) {
        self.puzzleSeed = puzzleSeed
        self.difficulty = puzzleSeed.difficulty
        self.startedFromCustomSeed = startedFromCustomSeed
        let generated = PuzzleGenerator.generate(seed: puzzleSeed.seedValue, difficulty: puzzleSeed.difficulty)
        applyGenerated(generated)
    }

    private func applyGenerated(_ generated: GeneratedPuzzle) {
        solution = generated.solution
        givens = generated.givens
        values = generated.puzzle
        notes = Self.emptyNotes()
        selected = nil
        highlightedDigit = nil
        isComplete = false
        mistakeCells = []
        mistakesThisPuzzle = 0
        usedNotesThisPuzzle = false
        completedRows = []
        completedCols = []
        completedBoxes = []
        pulseRows = []
        pulseCols = []
        pulseBoxes = []
        clearUndoHistory()
        noteSave()
    }

    static func restored(from state: SavedGameState) -> GameViewModel {
        let game = GameViewModel(
            puzzleSeed: state.puzzleSeed,
            startedFromCustomSeed: state.startedFromCustomSeed
        )
        game.values = state.values
        game.notes = state.notes.map { row in
            row.map { Set($0) }
        }
        game.isPencilMode = state.isPencilMode
        game.selected = state.selected
        game.highlightedDigit = state.highlightedDigit
        game.isComplete = state.isComplete
        game.usedNotesThisPuzzle = state.notes.contains { row in
            row.contains { !$0.isEmpty }
        }
        game.refreshMistakes()
        return game
    }

    func select(_ index: CellIndex) {
        guard acceptsInput else { return }
        focusCell(index)
    }

    /// Moves the selection with arrow keys / WASD; works while paused.
    func moveSelection(deltaRow: Int, deltaCol: Int) {
        guard !isComplete else { return }
        let row: Int
        let col: Int
        if let selected {
            row = min(8, max(0, selected.row + deltaRow))
            col = min(8, max(0, selected.col + deltaCol))
        } else {
            row = min(8, max(0, 4 + deltaRow))
            col = min(8, max(0, 4 + deltaCol))
        }
        focusCell(CellIndex(row: row, col: col))
    }

    /// Clears the selected cell from the keyboard (allowed while paused).
    func keyboardClearSelected() {
        guard !isComplete, let selected, !givens.contains(selected) else { return }
        if isPencilMode {
            guard !notes[selected.row][selected.col].isEmpty else { return }
            recordUndo(at: selected)
            notes[selected.row][selected.col] = []
            noteSave()
            return
        }
        guard values[selected.row][selected.col] != nil else { return }
        recordUndo(at: selected)
        values[selected.row][selected.col] = nil
        refreshMistakes()
        checkWin()
        noteSave()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        pushRedoSnapshot(at: snapshot.index)
        applySnapshot(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        pushUndoSnapshot(at: snapshot.index)
        applySnapshot(snapshot)
    }

    private func focusCell(_ index: CellIndex) {
        selected = index
        if let v = values[index.row][index.col] {
            highlightedDigit = v
        } else if let note = notes[index.row][index.col].first, notes[index.row][index.col].count == 1 {
            highlightedDigit = note
        } else {
            highlightedDigit = nil
        }
        noteSave()
    }

    func highlightDigit(_ digit: Int) {
        guard acceptsInput else { return }
        guard isPencilMode || !isGuessDigitExhausted(digit) else { return }
        highlightedDigit = digit
        guard let selected, !givens.contains(selected) else { return }
        if isPencilMode {
            guard values[selected.row][selected.col] == nil else { return }
            toggleNote(digit, at: selected)
            return
        }
        setValue(digit, at: selected)
        noteSave()
    }

    func togglePencilMode() {
        guard acceptsInput else { return }
        isPencilMode.toggle()
        noteSave()
    }

    func clearHighlight() {
        guard acceptsInput else { return }
        highlightedDigit = nil
        noteSave()
    }

    func setValue(_ digit: Int, at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        guard (1...9).contains(digit) else { return }
        guard !isGuessDigitExhausted(digit) else { return }
        guard values[index.row][index.col] != digit else { return }
        recordUndo(at: index)
        values[index.row][index.col] = digit
        notes[index.row][index.col] = []
        highlightedDigit = digit
        if digit != solution[index.row][index.col] {
            mistakesThisPuzzle += 1
            AchievementStore.recordMistake(difficulty: difficulty)
        }
        refreshMistakes()
        checkUnitCompletions()
        checkWin()
        noteSave()
    }

    func clearValue(at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        if isPencilMode {
            guard !notes[index.row][index.col].isEmpty else { return }
            recordUndo(at: index)
            notes[index.row][index.col] = []
            noteSave()
            return
        }
        guard values[index.row][index.col] != nil else { return }
        recordUndo(at: index)
        values[index.row][index.col] = nil
        refreshMistakes()
        checkWin()
        noteSave()
    }

    func toggleNote(_ digit: Int, at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        guard values[index.row][index.col] == nil else { return }
        guard (1...9).contains(digit) else { return }
        recordUndo(at: index)
        if notes[index.row][index.col].contains(digit) {
            notes[index.row][index.col].remove(digit)
        } else {
            notes[index.row][index.col].insert(digit)
            usedNotesThisPuzzle = true
        }
        highlightedDigit = digit
        noteSave()
    }

    func handleKey(_ key: String) {
        guard acceptsInput else { return }
        guard let selected else { return }
        let lowered = key.lowercased()
        if lowered == "delete" || lowered == "backspace" || key == "\u{7F}" || key == "\u{8}" {
            clearValue(at: selected)
            return
        }
        guard key.count == 1, let digit = Int(key), (1...9).contains(digit) else { return }
        if isPencilMode {
            toggleNote(digit, at: selected)
        } else if !isGuessDigitExhausted(digit) {
            setValue(digit, at: selected)
        }
        noteSave()
    }

    func isGiven(_ index: CellIndex) -> Bool {
        givens.contains(index)
    }

    /// True when every cell that should contain `digit` in the solution already shows that digit (guesser pad).
    func isGuessDigitExhausted(_ digit: Int) -> Bool {
        guard (1...9).contains(digit) else { return true }
        for r in 0..<9 {
            for c in 0..<9 where solution[r][c] == digit {
                if values[r][c] != digit {
                    return false
                }
            }
        }
        return true
    }

    var hasPlayerEntries: Bool {
        for r in 0..<9 {
            for c in 0..<9 {
                let index = CellIndex(row: r, col: c)
                if !givens.contains(index) {
                    if values[r][c] != nil || !notes[r][c].isEmpty {
                        return true
                    }
                }
            }
        }
        return false
    }

    func boxIndex(row: Int, col: Int) -> Int {
        (row / 3) * 3 + (col / 3)
    }

    private static func emptyNotes() -> [[Set<Int>]] {
        Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
    }

    // MARK: - Private

    private var acceptsInput: Bool {
        isInputEnabled && !isComplete
    }

    func refreshMistakes() {
        guard revealMistakesImmediately else {
            mistakeCells = []
            return
        }
        var mistakes = Set<CellIndex>()
        for r in 0..<9 {
            for c in 0..<9 {
                guard let v = values[r][c], !givens.contains(CellIndex(row: r, col: c)) else { continue }
                if v != solution[r][c] {
                    mistakes.insert(CellIndex(row: r, col: c))
                }
            }
        }
        mistakeCells = mistakes
    }

    private func checkWin() {
        for r in 0..<9 {
            for c in 0..<9 {
                guard values[r][c] == solution[r][c] else {
                    isComplete = false
                    return
                }
            }
        }
        isComplete = true
        noteSave()
    }

    private func noteSave() {
        refreshEditCommandState()
        saveRevision += 1
    }

    private func recordUndo(at index: CellIndex) {
        undoStack.append(snapshot(at: index))
        redoStack.removeAll()
        refreshEditCommandState()
    }

    private func pushRedoSnapshot(at index: CellIndex) {
        redoStack.append(snapshot(at: index))
        refreshEditCommandState()
    }

    private func pushUndoSnapshot(at index: CellIndex) {
        undoStack.append(snapshot(at: index))
        refreshEditCommandState()
    }

    private func snapshot(at index: CellIndex) -> CellEditSnapshot {
        CellEditSnapshot(
            index: index,
            value: values[index.row][index.col],
            notes: notes[index.row][index.col]
        )
    }

    private func applySnapshot(_ snapshot: CellEditSnapshot) {
        let index = snapshot.index
        values[index.row][index.col] = snapshot.value
        notes[index.row][index.col] = snapshot.notes
        if let v = snapshot.value {
            highlightedDigit = v
        } else if let note = snapshot.notes.first, snapshot.notes.count == 1 {
            highlightedDigit = note
        }
        refreshMistakes()
        checkWin()
        refreshEditCommandState()
        noteSave()
    }

    private func clearUndoHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        refreshEditCommandState()
    }

    private func refreshEditCommandState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        canDelete = computeCanDelete()
    }

    private func computeCanDelete() -> Bool {
        guard !isComplete, let selected, !givens.contains(selected) else { return false }
        if isPencilMode {
            return !notes[selected.row][selected.col].isEmpty
        }
        return values[selected.row][selected.col] != nil
    }

    private func checkUnitCompletions() {
        for r in 0..<9 where rowIsCorrectAndFull(r) && !completedRows.contains(r) {
            completedRows.insert(r)
            triggerPulse(row: r)
        }
        for c in 0..<9 where colIsCorrectAndFull(c) && !completedCols.contains(c) {
            completedCols.insert(c)
            triggerPulse(col: c)
        }
        for b in 0..<9 where boxIsCorrectAndFull(b) && !completedBoxes.contains(b) {
            completedBoxes.insert(b)
            triggerPulse(box: b)
        }
    }

    private func rowIsCorrectAndFull(_ row: Int) -> Bool {
        for c in 0..<9 {
            guard values[row][c] == solution[row][c] else { return false }
        }
        return true
    }

    private func colIsCorrectAndFull(_ col: Int) -> Bool {
        for r in 0..<9 {
            guard values[r][col] == solution[r][col] else { return false }
        }
        return true
    }

    private func boxIsCorrectAndFull(_ box: Int) -> Bool {
        let startRow = (box / 3) * 3
        let startCol = (box % 3) * 3
        for r in startRow..<(startRow + 3) {
            for c in startCol..<(startCol + 3) {
                guard values[r][c] == solution[r][c] else { return false }
            }
        }
        return true
    }

    private func triggerPulse(row: Int) {
        pulseRows.insert(row)
        clearPulseAfterDelay { self.pulseRows.remove(row) }
    }

    private func triggerPulse(col: Int) {
        pulseCols.insert(col)
        clearPulseAfterDelay { self.pulseCols.remove(col) }
    }

    private func triggerPulse(box: Int) {
        pulseBoxes.insert(box)
        clearPulseAfterDelay { self.pulseBoxes.remove(box) }
    }

    private func clearPulseAfterDelay(_ remove: @escaping () -> Void) {
        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            remove()
        }
    }
}
