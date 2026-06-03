import Combine
import Foundation
import SwiftUI

/// Board + `outcome` are puzzle state (`puzzleRevision`). Selection, pencil mode, etc. are session (`sessionRevision`).
@MainActor
final class GameViewModel: ObservableObject {
    // MARK: - Puzzle (board + outcome)

    @Published private(set) var puzzleSeed: PuzzleSeed
    @Published var difficulty: GameDifficulty
    @Published private(set) var startedFromCustomSeed = false
    @Published private(set) var solution: [[Int]]
    @Published private(set) var givens: Set<CellIndex>
    @Published var values: [[Int?]]
    @Published var notes: [[Set<Int>]]
    @Published private(set) var outcome: PuzzleOutcome = .playing
    @Published private(set) var mistakesThisPuzzle = 0
    @Published private(set) var usedNotesThisPuzzle = false
    /// Bumped after board/outcome edits; triggers puzzle persist in `ContentView`.
    @Published private(set) var puzzleRevision = 0

    // MARK: - Session UI (persisted via `sessionRevision`, not each cell fill)

    @Published var isPencilMode = false
    @Published var selected: CellIndex?
    @Published var highlightedDigit: Int?
    /// Bumped when session chrome changes (selection, pencil mode, etc.).
    @Published private(set) var sessionRevision = 0
    @Published var pulseRows: Set<Int> = []
    @Published var pulseCols: Set<Int> = []
    @Published var pulseBoxes: Set<Int> = []
    @Published var pulseDigits: Set<Int> = []
    @Published private(set) var puzzleCompletePulseGeneration: UInt = 0

    // MARK: - Derived / settings

    @Published var mistakeCells: Set<CellIndex> = []
    var revealMistakesImmediately = false
    var impossibleMode = false
    /// When false, board and keyboard input are ignored (paused, unfocused, or complete).
    var isInputEnabled = true
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var canDelete = false

    var isPuzzleEnded: Bool { outcome.isEnded }

    private var undoStack: [PuzzleSnapshot] = []
    private var redoStack: [PuzzleSnapshot] = []
    private var completedRows: Set<Int> = []
    private var completedCols: Set<Int> = []
    private var completedBoxes: Set<Int> = []
    private var completedDigits: Set<Int> = []

    init(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool,
        template: GeneratedPuzzle
    ) {
        self.puzzleSeed = puzzleSeed
        self.difficulty = puzzleSeed.difficulty
        self.startedFromCustomSeed = startedFromCustomSeed
        solution = []
        givens = []
        values = []
        notes = Self.emptyNotes()
        applyGenerated(template)
    }

    /// Resets progress on the current puzzle without re-running generation or validity checks.
    func replayCurrentPuzzle() {
        guard !givens.isEmpty else {
            start(puzzleSeed: puzzleSeed, startedFromCustomSeed: startedFromCustomSeed, validateRemovals: false)
            return
        }
        resetBoardToInitialClues()
    }

    func start(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool = false,
        validateRemovals: Bool = true
    ) {
        self.puzzleSeed = puzzleSeed
        self.difficulty = puzzleSeed.difficulty
        self.startedFromCustomSeed = startedFromCustomSeed
        let generated = PuzzleGenerator.generate(
            seed: puzzleSeed.seedValue,
            difficulty: puzzleSeed.difficulty,
            validateRemovals: validateRemovals
        )
        applyGenerated(generated)
    }

    private func resetBoardToInitialClues() {
        var puzzle = Array(repeating: Array(repeating: nil as Int?, count: 9), count: 9)
        for index in givens {
            puzzle[index.row][index.col] = solution[index.row][index.col]
        }
        values = puzzle
        notes = Self.emptyNotes()
        selected = nil
        highlightedDigit = nil
        outcome = .playing
        mistakeCells = []
        mistakesThisPuzzle = 0
        usedNotesThisPuzzle = false
        isPencilMode = false
        pulseRows = []
        pulseCols = []
        pulseBoxes = []
        pulseDigits = []
        puzzleCompletePulseGeneration = 0
        completedRows = []
        completedCols = []
        completedBoxes = []
        completedDigits = []
        clearUndoHistory()
        syncCompletedCelebrations()
        publishPuzzleRevision()
    }

    static func restored(from state: SavedGameState, template: GeneratedPuzzle) -> GameViewModel {
        let game = GameViewModel(
            puzzleSeed: state.puzzleSeed,
            startedFromCustomSeed: state.startedFromCustomSeed,
            template: template
        )
        game.applySavedProgress(from: state)
        return game
    }

    func applySavedProgress(from state: SavedGameState) {
        values = state.values
        notes = state.notes.map { row in
            row.map { Set($0) }
        }
        outcome = state.outcome
        mistakesThisPuzzle = state.mistakesThisPuzzle
        usedNotesThisPuzzle = state.notes.contains { row in
            row.contains { !$0.isEmpty }
        }
        isPencilMode = state.isPencilMode
        selected = state.selected
        highlightedDigit = state.highlightedDigit
        refreshMistakes()
        refreshEditCommandState()
        syncCompletedCelebrations()
    }

    /// Cells that contain `digit` in the solved grid (for digit-completion pulse layout).
    func solutionIndices(for digit: Int) -> [CellIndex] {
        guard (1...9).contains(digit) else { return [] }
        return (0..<9).flatMap { row in
            (0..<9).compactMap { col in
                solution[row][col] == digit ? CellIndex(row: row, col: col) : nil
            }
        }
    }

    // MARK: - Session UI

    func select(_ index: CellIndex) {
        guard acceptsInput else { return }
        focusCell(index)
    }

    func moveSelection(deltaRow: Int, deltaCol: Int) {
        guard acceptsInput else { return }
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
    }

    func togglePencilMode() {
        guard acceptsInput else { return }
        isPencilMode.toggle()
        refreshEditCommandState()
        touchSession()
    }

    func clearHighlight() {
        guard acceptsInput else { return }
        highlightedDigit = nil
    }

    // MARK: - Puzzle mutations

    func keyboardClearSelected() {
        guard acceptsInput, let selected, !givens.contains(selected) else { return }
        if isPencilMode {
            guard !notes[selected.row][selected.col].isEmpty else { return }
            mutatePuzzle(undoAt: selected) {
                notes[selected.row][selected.col] = []
            }
            return
        }
        guard values[selected.row][selected.col] != nil else { return }
        mutatePuzzle(undoAt: selected) {
            values[selected.row][selected.col] = nil
        }
    }

    func undo() {
        travelPuzzleHistory(popFrom: &undoStack, pushTo: &redoStack)
    }

    func redo() {
        travelPuzzleHistory(popFrom: &redoStack, pushTo: &undoStack)
    }

    func setValue(_ digit: Int, at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        guard (1...9).contains(digit) else { return }
        guard !isGuessDigitExhausted(digit) else { return }
        guard values[index.row][index.col] != digit else { return }
        let peersToClear = peersNeedingNoteRemoval(for: digit, placedAt: index)
        var undoCells = [snapshot(at: index)]
        undoCells.append(contentsOf: peersToClear.map(snapshot(at:)))
        mutatePuzzle(undoCells: undoCells) {
            values[index.row][index.col] = digit
            notes[index.row][index.col] = []
            for peer in peersToClear {
                notes[peer.row][peer.col].remove(digit)
            }
            highlightedDigit = digit
            if digit != solution[index.row][index.col] {
                mistakesThisPuzzle += 1
                AchievementStore.recordMistake(difficulty: difficulty)
                if impossibleMode {
                    outcome = .lost
                }
            }
            checkUnitCompletions()
        }
    }

    func clearValue(at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        if isPencilMode {
            guard !notes[index.row][index.col].isEmpty else { return }
            mutatePuzzle(undoAt: index) {
                notes[index.row][index.col] = []
            }
            return
        }
        guard values[index.row][index.col] != nil else { return }
        mutatePuzzle(undoAt: index) {
            values[index.row][index.col] = nil
        }
    }

    func toggleNote(_ digit: Int, at index: CellIndex) {
        guard acceptsInput else { return }
        guard !givens.contains(index) else { return }
        guard values[index.row][index.col] == nil else { return }
        guard (1...9).contains(digit) else { return }
        mutatePuzzle(undoAt: index) {
            if notes[index.row][index.col].contains(digit) {
                notes[index.row][index.col].remove(digit)
            } else {
                notes[index.row][index.col].insert(digit)
                usedNotesThisPuzzle = true
            }
            highlightedDigit = digit
        }
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

    // MARK: - Private

    private var acceptsInput: Bool {
        isInputEnabled && !isPuzzleEnded
    }

    private static func emptyNotes() -> [[Set<Int>]] {
        Array(repeating: Array(repeating: Set<Int>(), count: 9), count: 9)
    }

    private func applyGenerated(_ generated: GeneratedPuzzle) {
        solution = generated.solution
        givens = generated.givens
        values = generated.puzzle
        notes = Self.emptyNotes()
        selected = nil
        highlightedDigit = nil
        outcome = .playing
        mistakeCells = []
        mistakesThisPuzzle = 0
        usedNotesThisPuzzle = false
        completedRows = []
        completedCols = []
        completedBoxes = []
        completedDigits = []
        pulseRows = []
        pulseCols = []
        pulseBoxes = []
        pulseDigits = []
        puzzleCompletePulseGeneration = 0
        clearUndoHistory()
        syncCompletedCelebrations()
        publishPuzzleRevision()
    }

    private func mutatePuzzle(undoAt index: CellIndex, apply: () -> Void) {
        mutatePuzzle(undoCells: [snapshot(at: index)], apply: apply)
    }

    /// Records pre-edit snapshot, applies board change, then derives win from the grid.
    private func mutatePuzzle(undoCells: [CellEditSnapshot], apply: () -> Void) {
        undoStack.append(PuzzleSnapshot(cells: undoCells, outcome: outcome, mistakesThisPuzzle: mistakesThisPuzzle))
        redoStack.removeAll()
        apply()
        reconcilePuzzleOutcome()
        publishPuzzleRevision()
    }

    /// Undo/redo travel the same snapshot path as forward edits, in reverse.
    private func travelPuzzleHistory(popFrom source: inout [PuzzleSnapshot], pushTo destination: inout [PuzzleSnapshot]) {
        guard let target = source.popLast() else { return }
        destination.append(
            PuzzleSnapshot(
                cells: target.cells.map { snapshot(at: $0.index) },
                outcome: outcome,
                mistakesThisPuzzle: mistakesThisPuzzle
            )
        )
        applyPuzzleSnapshot(target)
        refreshMistakes()
        if let selected {
            focusCell(selected, touchSession: false)
        }
        publishPuzzleRevision()
    }

    private func applyPuzzleSnapshot(_ snapshot: PuzzleSnapshot) {
        for cell in snapshot.cells {
            values[cell.index.row][cell.index.col] = cell.value
            notes[cell.index.row][cell.index.col] = cell.notes
        }
        outcome = snapshot.outcome
        mistakesThisPuzzle = snapshot.mistakesThisPuzzle
    }

    /// Win only when the board is full and correct; loss is set on impossible-mode mistakes.
    private func reconcilePuzzleOutcome() {
        refreshMistakes()
        guard outcome == .playing else { return }
        guard boardMatchesSolution() else { return }
        outcome = .won
        triggerPuzzleCompletePulse()
    }

    private func touchSession() {
        sessionRevision += 1
    }

    private func boardMatchesSolution() -> Bool {
        for r in 0..<9 {
            for c in 0..<9 where values[r][c] != solution[r][c] {
                return false
            }
        }
        return true
    }

    private func publishPuzzleRevision() {
        refreshEditCommandState()
        puzzleRevision += 1
    }

    private func snapshot(at index: CellIndex) -> CellEditSnapshot {
        CellEditSnapshot(
            index: index,
            value: values[index.row][index.col],
            notes: notes[index.row][index.col]
        )
    }

    /// Empty cells in the same row, column, or box that still list `digit` as a pencil mark.
    private func peersNeedingNoteRemoval(for digit: Int, placedAt index: CellIndex) -> [CellIndex] {
        unitPeers(of: index).filter { peer in
            values[peer.row][peer.col] == nil && notes[peer.row][peer.col].contains(digit)
        }
    }

    private func unitPeers(of index: CellIndex) -> [CellIndex] {
        let row = index.row
        let col = index.col
        var peers: Set<CellIndex> = []
        for c in 0..<9 where c != col {
            peers.insert(CellIndex(row: row, col: c))
        }
        for r in 0..<9 where r != row {
            peers.insert(CellIndex(row: r, col: col))
        }
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) where r != row || c != col {
                peers.insert(CellIndex(row: r, col: c))
            }
        }
        return Array(peers)
    }

    private func focusCell(_ index: CellIndex, touchSession: Bool = true) {
        selected = index
        if let v = values[index.row][index.col] {
            highlightedDigit = v
        } else if let note = notes[index.row][index.col].first, notes[index.row][index.col].count == 1 {
            highlightedDigit = note
        } else {
            highlightedDigit = nil
        }
        refreshEditCommandState()
        if touchSession {
            self.touchSession()
        }
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
        guard !isPuzzleEnded, let selected, !givens.contains(selected) else { return false }
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
        for digit in 1...9 where isGuessDigitExhausted(digit) && !completedDigits.contains(digit) {
            completedDigits.insert(digit)
            triggerPulse(digit: digit)
        }
    }

    /// Marks units/digits already complete on load so we do not replay celebration pulses.
    private func syncCompletedCelebrations() {
        completedRows = Set((0..<9).filter(rowIsCorrectAndFull))
        completedCols = Set((0..<9).filter(colIsCorrectAndFull))
        completedBoxes = Set((0..<9).filter(boxIsCorrectAndFull))
        completedDigits = Set((1...9).filter(isGuessDigitExhausted))
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

    private func triggerPuzzleCompletePulse() {
        puzzleCompletePulseGeneration &+= 1
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

    private func triggerPulse(digit: Int) {
        pulseDigits.insert(digit)
        clearPulseAfterDelay { self.pulseDigits.remove(digit) }
    }

    private func clearPulseAfterDelay(_ remove: @escaping () -> Void) {
        Task {
            try? await Task.sleep(nanoseconds: 920_000_000)
            remove()
        }
    }

    #if DEBUG
    func debugTriggerPuzzleCompletePulse() {
        triggerPuzzleCompletePulse()
    }

    func debugTriggerFinishedRowPulse() {
        triggerPulse(row: 4)
    }

    func debugTriggerFinishedColumnPulse() {
        triggerPulse(col: 4)
    }

    func debugTriggerFinishedBoxPulse() {
        triggerPulse(box: 4)
    }

    func debugTriggerFinishedDigitPulse() {
        triggerPulse(digit: 5)
    }
    #endif
}

private struct PuzzleSnapshot {
    let cells: [CellEditSnapshot]
    let outcome: PuzzleOutcome
    let mistakesThisPuzzle: Int
}
