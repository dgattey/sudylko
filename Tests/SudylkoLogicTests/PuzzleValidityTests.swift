import XCTest
@testable import Sudylko

final class PuzzleValidityTests: XCTestCase {
    func testGeneratedPuzzlesAreUniqueAndLogicSolvable() {
        let numbers = [1, 42, 1384, 4242, 99_999]
        for difficulty in GameDifficulty.allCases {
            for number in numbers {
                let generated = PuzzleGenerator.generate(
                    seed: PuzzleSeed(number: number, difficulty: difficulty).seedValue,
                    difficulty: difficulty
                )
                XCTAssertTrue(
                    PuzzleValidity.hasUniqueSolution(puzzle: generated.puzzle),
                    "\(difficulty) #\(number) should have one solution"
                )
                XCTAssertTrue(
                    PuzzleValidity.isSolvableWithoutGuessing(puzzle: generated.puzzle),
                    "\(difficulty) #\(number) should not require guessing"
                )
                for index in generated.givens {
                    let r = index.row
                    let c = index.col
                    XCTAssertEqual(generated.puzzle[r][c], generated.solution[r][c])
                }
            }
        }
    }

    func testEmptyGridHasMultipleSolutions() {
        let empty = Array(repeating: Array(repeating: nil as Int?, count: 9), count: 9)
        XCTAssertGreaterThan(PuzzleValidity.solutionCount(puzzle: empty, limit: 2), 1)
    }
}
