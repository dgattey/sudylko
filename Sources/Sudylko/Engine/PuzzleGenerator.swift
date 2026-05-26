import Foundation

struct GeneratedPuzzle {
    /// 9×9 solution grid (1–9).
    let solution: [[Int]]
    /// 9×9 puzzle; `nil` = empty cell.
    let puzzle: [[Int?]]
    let givens: Set<CellIndex>
}

struct CellIndex: Hashable, Sendable {
    let row: Int
    let col: Int
}

enum PuzzleGenerator {
    private static let size = 9
    private static let box = 3

    static func generate(seed: UInt64, difficulty: GameDifficulty) -> GeneratedPuzzle {
        var rng = SeededRNG(seed: seed)
        var solution = Array(repeating: Array(repeating: 0, count: size), count: size)

        fillDiagonalBoxes(grid: &solution, rng: &rng)
        _ = solve(grid: &solution, rng: &rng)

        var puzzle = solution.map { row in row.map { Optional($0) } }
        var givens = Set<CellIndex>()
        for r in 0..<size {
            for c in 0..<size {
                givens.insert(CellIndex(row: r, col: c))
            }
        }

        var cells = (0..<size).flatMap { r in (0..<size).map { c in CellIndex(row: r, col: c) } }
        rng.shuffle(&cells)

        var removed = 0
        let target = difficulty.cellsToRemove
        for index in cells where removed < target {
            let r = index.row
            let c = index.col
            guard puzzle[r][c] != nil else { continue }
            puzzle[r][c] = nil
            givens.remove(index)
            removed += 1
        }

        return GeneratedPuzzle(
            solution: solution,
            puzzle: puzzle,
            givens: givens
        )
    }

    // MARK: - Generation helpers

    private static func fillDiagonalBoxes(grid: inout [[Int]], rng: inout SeededRNG) {
        for boxIndex in 0..<box {
            var nums = Array(1...9)
            rng.shuffle(&nums)
            let startRow = boxIndex * box
            let startCol = boxIndex * box
            var n = 0
            for r in startRow..<(startRow + box) {
                for c in startCol..<(startCol + box) {
                    grid[r][c] = nums[n]
                    n += 1
                }
            }
        }
    }

    private static func solve(grid: inout [[Int]], rng: inout SeededRNG) -> Bool {
        guard let empty = findEmpty(in: grid) else { return true }
        var candidates = Array(1...9)
        rng.shuffle(&candidates)
        for value in candidates where isValid(value, row: empty.row, col: empty.col, in: grid) {
            grid[empty.row][empty.col] = value
            if solve(grid: &grid, rng: &rng) { return true }
            grid[empty.row][empty.col] = 0
        }
        return false
    }

    private static func findEmpty(in grid: [[Int]]) -> CellIndex? {
        for r in 0..<size {
            for c in 0..<size where grid[r][c] == 0 {
                return CellIndex(row: r, col: c)
            }
        }
        return nil
    }

    private static func isValid(_ value: Int, row: Int, col: Int, in grid: [[Int]]) -> Bool {
        for c in 0..<size where grid[row][c] == value && c != col { return false }
        for r in 0..<size where grid[r][col] == value && r != row { return false }
        let boxRow = (row / box) * box
        let boxCol = (col / box) * box
        for r in boxRow..<(boxRow + box) {
            for c in boxCol..<(boxCol + box) where grid[r][c] == value && (r != row || c != col) {
                return false
            }
        }
        return true
    }
}
