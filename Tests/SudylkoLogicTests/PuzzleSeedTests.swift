import XCTest
@testable import Sudylko

final class PuzzleSeedTests: XCTestCase {
    func testParseAcceptsHashPrefixAndFiveDigits() {
        XCTAssertEqual(PuzzleSeed.parse("#89799", difficulty: .hard)?.number, 89799)
        XCTAssertEqual(PuzzleSeed.parse("89799", difficulty: .hard)?.number, 89799)
        XCTAssertEqual(PuzzleSeed.parse("  #89799  ", difficulty: .hard)?.number, 89799)
    }

    func testParseStripsGamePrefix() {
        XCTAssertEqual(PuzzleSeed.parse("Game #4242", difficulty: .medium)?.number, 4242)
    }

    func testSanitizedInputKeepsHashPrefixAndCapsLength() {
        XCTAssertEqual(PuzzleSeed.sanitizedInput("#89799"), "#89799")
        XCTAssertEqual(PuzzleSeed.sanitizedInput("#89799extra"), "#89799")
        XCTAssertEqual(PuzzleSeed.sanitizedInput("8979912345"), "89799")
    }

    func testPrefillFromClipboardAcceptsHashInPasteboard() {
        Clipboard.copy("#89799")
        let prefill = PuzzleSeed.prefillFromClipboard(defaultDifficulty: .hard)
        XCTAssertEqual(prefill?.text, "#89799")
        XCTAssertEqual(prefill?.difficulty, .hard)
    }

    func testClipboardTextIsPlainNumber() {
        let seed = PuzzleSeed(number: 89799, difficulty: .hard)
        XCTAssertEqual(seed.clipboardText, "89799")
    }

    func testNormalizedDigitString() {
        XCTAssertEqual(PuzzleSeed.normalizedDigitString(from: "#89799"), "89799")
        XCTAssertEqual(
            PuzzleSeed.normalizedDigitString(from: "Copied #89799 (Hard) to clipboard"),
            "89799"
        )
    }
}
