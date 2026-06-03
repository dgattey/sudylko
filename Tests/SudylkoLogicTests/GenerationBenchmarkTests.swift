import XCTest
@testable import Sudylko

final class GenerationBenchmarkTests: XCTestCase {
    func testHard89799GenerationTime() {
        let seed = PuzzleSeed(number: 89799, difficulty: .hard).seedValue
        let start = CFAbsoluteTimeGetCurrent()
        _ = PuzzleGenerator.generate(seed: seed, difficulty: .hard, validateRemovals: true)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("hard #89799 generate: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 2.0, "hard #89799 should generate in under 2s")
    }
}
