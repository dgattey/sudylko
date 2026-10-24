#if os(macOS)
import AppKit
import XCTest
@testable import Sudylko

@MainActor
final class BoardKeyboardHostTests: XCTestCase {
    func testNTogglesNotesMode() throws {
        let (game, view) = makeHost()
        XCTAssertFalse(game.isPencilMode, "notes mode starts off")

        try press("n", keyCode: 45, on: view)
        XCTAssertTrue(game.isPencilMode, "N turns notes mode on")

        try press("n", keyCode: 45, on: view)
        XCTAssertFalse(game.isPencilMode, "a second N turns notes mode off")
    }

    func testNavigationClearAndSpaceLeaveNotesModeOff() throws {
        let (game, view) = makeHost()
        let keys: [(characters: String, keyCode: UInt16)] = [
            ("w", 13),
            ("a", 0),
            ("s", 1),
            ("d", 2),
            ("e", 14),
            (" ", 49)
        ]
        for key in keys {
            try press(key.characters, keyCode: key.keyCode, on: view)
            XCTAssertFalse(game.isPencilMode, "\"\(key.characters)\" leaves notes mode off")
        }
    }

    func testNLeavesNotesModeOffWhenInputIsDisabled() throws {
        let (game, view) = makeHost()
        game.isInputEnabled = false

        try press("n", keyCode: 45, on: view)
        XCTAssertFalse(game.isPencilMode, "N leaves notes mode off when input is disabled")
    }

    private func makeHost() -> (GameViewModel, BoardKeyboardHost.KeyboardNSView) {
        let seed = PuzzleSeed(number: 1, difficulty: .easy)
        let game = GameViewModel(
            puzzleSeed: seed,
            startedFromCustomSeed: false,
            template: PuzzleGenerator.generate(seed: seed.seedValue, difficulty: .easy)
        )
        let view = BoardKeyboardHost.KeyboardNSView(frame: .zero)
        view.game = game
        return (game, view)
    }

    private func press(
        _ characters: String,
        keyCode: UInt16,
        on view: BoardKeyboardHost.KeyboardNSView
    ) throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode
            ),
            "key event for \(characters)"
        )
        view.keyDown(with: event)
    }
}
#endif
