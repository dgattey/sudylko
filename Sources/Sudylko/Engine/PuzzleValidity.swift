import Foundation

/// Checks unique solutions and logic-only solvability (no bifurcation guessing).
enum PuzzleValidity {
    private static let size = 9
    private static let box = 3

    static func hasUniqueSolution(puzzle: [[Int?]]) -> Bool {
        solutionCount(puzzle: puzzle, limit: 2) == 1
    }

    static func isSolvableWithoutGuessing(puzzle: [[Int?]]) -> Bool {
        var solver = LogicOnlySolver(puzzle: puzzle)
        return solver.solve()
    }

    /// Stops once `limit` solutions have been found.
    static func solutionCount(puzzle: [[Int?]], limit: Int = 2) -> Int {
        guard limit > 0 else { return 0 }
        var board = CandidateBoard(puzzle: puzzle)
        return board.countSolutions(limit: limit)
    }
}

// MARK: - Bitmask candidate grid (uniqueness counting)

private struct CandidateBoard {
    private static let size = 9
    private static let box = 3
    private static let allDigits: UInt16 = 0b1_111_111_110

    private var values: [[Int]]
    private var candidates: [[UInt16]]

    init(puzzle: [[Int?]]) {
        values = puzzle.map { row in row.map { $0 ?? 0 } }
        candidates = Self.initialCandidates(values: values)
    }

    mutating func countSolutions(limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        return countSolutions(limit: limit, depth: 0)
    }

    private mutating func countSolutions(limit: Int, depth: Int) -> Int {
        guard let empty = mrvEmpty() else { return 1 }
        let savedValues = values
        let savedCandidates = candidates
        var total = 0
        var options = candidates[empty.row][empty.col]
        while options != 0 {
            let digit = options.trailingZeroBitCount
            options &= options - 1
            guard digit != 0, digit <= 9 else { continue }
            values = savedValues
            candidates = savedCandidates
            place(digit, row: empty.row, col: empty.col)
            total += countSolutions(limit: limit, depth: depth + 1)
            if total >= limit { return total }
        }
        return total
    }

    private mutating func place(_ digit: Int, row: Int, col: Int) {
        values[row][col] = digit
        candidates[row][col] = 0
        eliminate(digit, row: row, col: col)
    }

    private mutating func eliminate(_ digit: Int, row: Int, col: Int) {
        let bit = UInt16(1 << digit)
        for c in 0..<Self.size where c != col && values[row][c] == 0 {
            candidates[row][c] &= ~bit
        }
        for r in 0..<Self.size where r != row && values[r][col] == 0 {
            candidates[r][col] &= ~bit
        }
        let boxRow = (row / Self.box) * Self.box
        let boxCol = (col / Self.box) * Self.box
        for r in boxRow..<(boxRow + Self.box) {
            for c in boxCol..<(boxCol + Self.box)
                where (r != row || c != col) && values[r][c] == 0 {
                candidates[r][c] &= ~bit
            }
        }
    }

    private func mrvEmpty() -> CellIndex? {
        var best: CellIndex?
        var bestCount = 10
        for r in 0..<Self.size {
            for c in 0..<Self.size where values[r][c] == 0 {
                let count = candidates[r][c].nonzeroBitCount
                if count == 0 { return CellIndex(row: r, col: c) }
                if count < bestCount {
                    bestCount = count
                    best = CellIndex(row: r, col: c)
                }
            }
        }
        return best
    }

    private static func initialCandidates(values: [[Int]]) -> [[UInt16]] {
        var result = Array(repeating: Array(repeating: allDigits, count: size), count: size)
        for r in 0..<size {
            for c in 0..<size {
                guard values[r][c] == 0 else {
                    result[r][c] = 0
                    continue
                }
                var possible = allDigits
                for col in 0..<size where values[r][col] != 0 {
                    possible &= ~(UInt16(1 << values[r][col]))
                }
                for row in 0..<size where values[row][c] != 0 {
                    possible &= ~(UInt16(1 << values[row][c]))
                }
                let boxRow = (r / box) * box
                let boxCol = (c / box) * box
                for row in boxRow..<(boxRow + box) {
                    for col in boxCol..<(boxCol + box) where values[row][col] != 0 {
                        possible &= ~(UInt16(1 << values[row][col]))
                    }
                }
                result[r][c] = possible
            }
        }
        return result
    }
}

// MARK: - Human-style techniques (singles + box/line reductions)

private struct LogicOnlySolver {
    private static let size = 9
    private static let box = 3

    private var values: [[Int?]]
    private var candidates: [[Set<Int>]]

    init(puzzle: [[Int?]]) {
        values = puzzle
        candidates = Self.computeCandidates(values)
    }

    mutating func solve() -> Bool {
        while step() { }
        guard isComplete else { return false }
        return !hasContradiction
    }

    private var isComplete: Bool {
        values.allSatisfy { row in row.allSatisfy { $0 != nil } }
    }

    private var hasContradiction: Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size where values[r][c] == nil && candidates[r][c].isEmpty {
                return true
            }
        }
        return false
    }

    @discardableResult
    private mutating func step() -> Bool {
        if placeNakedSingles() { return true }
        if placeHiddenSingles() { return true }
        if eliminateBoxLineInteractions() { return true }
        return false
    }

    private mutating func placeNakedSingles() -> Bool {
        var placed = false
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                guard values[r][c] == nil, candidates[r][c].count == 1,
                      let digit = candidates[r][c].first else { continue }
                place(digit, at: CellIndex(row: r, col: c))
                placed = true
            }
        }
        return placed
    }

    private mutating func placeHiddenSingles() -> Bool {
        var placed = false
        for r in 0..<Self.size {
            for digit in 1...9 {
                let cells = hiddenSingleCells(inRow: r, digit: digit)
                if cells.count == 1, let index = cells.first {
                    place(digit, at: index)
                    placed = true
                }
            }
        }
        for c in 0..<Self.size {
            for digit in 1...9 {
                let cells = hiddenSingleCells(inCol: c, digit: digit)
                if cells.count == 1, let index = cells.first {
                    place(digit, at: index)
                    placed = true
                }
            }
        }
        for box in 0..<Self.size {
            for digit in 1...9 {
                let cells = hiddenSingleCells(inBox: box, digit: digit)
                if cells.count == 1, let index = cells.first {
                    place(digit, at: index)
                    placed = true
                }
            }
        }
        return placed
    }

    private mutating func eliminateBoxLineInteractions() -> Bool {
        var changed = false
        for box in 0..<Self.size {
            let startRow = (box / Self.box) * Self.box
            let startCol = (box % Self.box) * Self.box
            for digit in 1...9 {
                var cells: [CellIndex] = []
                for r in startRow..<(startRow + Self.box) {
                    for c in startCol..<(startCol + Self.box) {
                        let index = CellIndex(row: r, col: c)
                        if values[r][c] == nil, candidates[r][c].contains(digit) {
                            cells.append(index)
                        }
                    }
                }
                guard !cells.isEmpty else { continue }

                let rows = Set(cells.map(\.row))
                if rows.count == 1, let row = rows.first {
                    for c in 0..<Self.size where c < startCol || c >= startCol + Self.box {
                        if values[row][c] == nil, candidates[row][c].remove(digit) != nil {
                            changed = true
                        }
                    }
                }

                let cols = Set(cells.map(\.col))
                if cols.count == 1, let col = cols.first {
                    for r in 0..<Self.size where r < startRow || r >= startRow + Self.box {
                        if values[r][col] == nil, candidates[r][col].remove(digit) != nil {
                            changed = true
                        }
                    }
                }
            }
        }

        for row in 0..<Self.size {
            for digit in 1...9 {
                var cells: [CellIndex] = []
                for c in 0..<Self.size {
                    if values[row][c] == nil, candidates[row][c].contains(digit) {
                        cells.append(CellIndex(row: row, col: c))
                    }
                }
                guard !cells.isEmpty else { continue }
                let boxes = Set(cells.map { Self.boxIndex(row: $0.row, col: $0.col) })
                if boxes.count == 1 {
                    let box = boxes.first!
                    let startRow = (box / Self.box) * Self.box
                    let startCol = (box % Self.box) * Self.box
                    for r in startRow..<(startRow + Self.box) where r != row {
                        for c in startCol..<(startCol + Self.box) {
                            if values[r][c] == nil, candidates[r][c].remove(digit) != nil {
                                changed = true
                            }
                        }
                    }
                }
            }
        }

        for col in 0..<Self.size {
            for digit in 1...9 {
                var cells: [CellIndex] = []
                for r in 0..<Self.size {
                    if values[r][col] == nil, candidates[r][col].contains(digit) {
                        cells.append(CellIndex(row: r, col: col))
                    }
                }
                guard !cells.isEmpty else { continue }
                let boxes = Set(cells.map { Self.boxIndex(row: $0.row, col: $0.col) })
                if boxes.count == 1 {
                    let box = boxes.first!
                    let startRow = (box / Self.box) * Self.box
                    let startCol = (box % Self.box) * Self.box
                    for c in startCol..<(startCol + Self.box) where c != col {
                        for r in startRow..<(startRow + Self.box) {
                            if values[r][c] == nil, candidates[r][c].remove(digit) != nil {
                                changed = true
                            }
                        }
                    }
                }
            }
        }

        return changed
    }

    private mutating func place(_ digit: Int, at index: CellIndex) {
        values[index.row][index.col] = digit
        candidates[index.row][index.col] = []
        eliminate(digit, excluding: index)
    }

    private mutating func eliminate(_ digit: Int, excluding index: CellIndex) {
        let row = index.row
        let col = index.col
        for c in 0..<Self.size where c != col && values[row][c] == nil {
            candidates[row][c].remove(digit)
        }
        for r in 0..<Self.size where r != row && values[r][col] == nil {
            candidates[r][col].remove(digit)
        }
        let boxRow = (row / Self.box) * Self.box
        let boxCol = (col / Self.box) * Self.box
        for r in boxRow..<(boxRow + Self.box) {
            for c in boxCol..<(boxCol + Self.box)
                where (r != row || c != col) && values[r][c] == nil {
                candidates[r][c].remove(digit)
            }
        }
    }

    private func hiddenSingleCells(inRow row: Int, digit: Int) -> [CellIndex] {
        (0..<Self.size).compactMap { c -> CellIndex? in
            guard values[row][c] == nil, candidates[row][c].contains(digit) else { return nil }
            return CellIndex(row: row, col: c)
        }
    }

    private func hiddenSingleCells(inCol col: Int, digit: Int) -> [CellIndex] {
        (0..<Self.size).compactMap { r -> CellIndex? in
            guard values[r][col] == nil, candidates[r][col].contains(digit) else { return nil }
            return CellIndex(row: r, col: col)
        }
    }

    private func hiddenSingleCells(inBox box: Int, digit: Int) -> [CellIndex] {
        let startRow = (box / Self.box) * Self.box
        let startCol = (box % Self.box) * Self.box
        var result: [CellIndex] = []
        for r in startRow..<(startRow + Self.box) {
            for c in startCol..<(startCol + Self.box) {
                guard values[r][c] == nil, candidates[r][c].contains(digit) else { continue }
                result.append(CellIndex(row: r, col: c))
            }
        }
        return result
    }

    private static func boxIndex(row: Int, col: Int) -> Int {
        (row / box) * box + (col / box)
    }

    private static func computeCandidates(_ values: [[Int?]]) -> [[Set<Int>]] {
        var result = Array(
            repeating: Array(repeating: Set<Int>(), count: size),
            count: size
        )
        for r in 0..<size {
            for c in 0..<size {
                guard values[r][c] == nil else {
                    result[r][c] = []
                    continue
                }
                var possible = Set(1...9)
                for col in 0..<size {
                    if let value = values[r][col] { possible.remove(value) }
                }
                for row in 0..<size {
                    if let value = values[row][c] { possible.remove(value) }
                }
                let boxRow = (r / box) * box
                let boxCol = (c / box) * box
                for row in boxRow..<(boxRow + box) {
                    for col in boxCol..<(boxCol + box) {
                        if let value = values[row][col] { possible.remove(value) }
                    }
                }
                result[r][c] = possible
            }
        }
        return result
    }
}
