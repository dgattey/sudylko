#if os(macOS)
import AppKit
import SwiftUI

/// Invisible first responder for keyboard input without a focus ring on the board.
struct BoardKeyboardHost: NSViewRepresentable {
    @ObservedObject var game: GameViewModel
    var onTogglePause: () -> Void
    /// Return `true` when Escape was handled (e.g. closing settings).
    var onEscape: () -> Bool = { false }
    var onGoHome: () -> Void

    func makeNSView(context: Context) -> KeyboardNSView {
        let view = KeyboardNSView()
        view.game = game
        view.onTogglePause = onTogglePause
        view.onEscape = onEscape
        view.onGoHome = onGoHome
        return view
    }

    func updateNSView(_ nsView: KeyboardNSView, context: Context) {
        nsView.game = game
        nsView.onTogglePause = onTogglePause
        nsView.onEscape = onEscape
        nsView.onGoHome = onGoHome
        DispatchQueue.main.async {
            if let window = nsView.window, window.firstResponder !== nsView {
                window.makeFirstResponder(nsView)
            }
        }
    }

    final class KeyboardNSView: NSView {
        weak var game: GameViewModel?
        var onTogglePause: (() -> Void)?
        var onEscape: (() -> Bool)?
        var onGoHome: (() -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            focusRingType = .none
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            focusRingType = .none
        }

        override var acceptsFirstResponder: Bool { true }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if SudylkoKeyEvent.isShiftQuestionMark(event) {
                return HelpMenuShortcutController.shared.performShortcut(from: self)
            }
            if Self.isDeleteKey(event) {
                return EditMenuDeleteController.shared.performDelete(from: self)
            }
            if SudylkoKeyEvent.isSpace(event) {
                let handled: Bool
                if Thread.isMainThread {
                    handled = MainActor.assumeIsolated { handleTogglePauseKey() }
                } else {
                    handled = DispatchQueue.main.sync { MainActor.assumeIsolated { handleTogglePauseKey() } }
                }
                if handled { return true }
            }
            return super.performKeyEquivalent(with: event)
        }

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.contains(.command) {
                super.keyDown(with: event)
                return
            }
            let handled: Bool
            if Thread.isMainThread {
                handled = MainActor.assumeIsolated { processKeyDown(event) }
            } else {
                handled = DispatchQueue.main.sync { MainActor.assumeIsolated { processKeyDown(event) } }
            }
            if !handled {
                super.keyDown(with: event)
            }
        }

        @MainActor
        private func handleTogglePauseKey() -> Bool {
            guard onTogglePause != nil else { return false }
            onTogglePause?()
            return true
        }

        @MainActor
        private func processKeyDown(_ event: NSEvent) -> Bool {
            guard let game else { return false }

            if event.keyCode == 53 {
                if onEscape?() == true { return true }
                onGoHome?()
                return true
            }

            if SudylkoKeyEvent.isSpace(event), handleTogglePauseKey() {
                return true
            }

            if let delta = Self.navigationDelta(for: event) {
                game.moveSelection(deltaRow: delta.row, deltaCol: delta.col)
                return true
            }

            if Self.isClearKey(event) {
                game.keyboardClearSelected()
                return true
            }

            if SudylkoKeyEvent.isShiftQuestionMark(event) {
                return HelpMenuShortcutController.shared.performShortcut(from: self)
            }

            guard game.isInputEnabled, !game.isPuzzleEnded else { return false }

            if let digit = Self.digit(from: event) {
                guard let selected = game.selected else { return true }
                if game.isPencilMode {
                    game.toggleNote(digit, at: selected)
                } else {
                    game.setValue(digit, at: selected)
                }
                return true
            }

            if let char = event.charactersIgnoringModifiers?.lowercased(), char.count == 1 {
                game.handleKey(char)
                return true
            }

            return false
        }

        private static func navigationDelta(for event: NSEvent) -> (row: Int, col: Int)? {
            switch event.keyCode {
            case 126: return (-1, 0)
            case 125: return (1, 0)
            case 123: return (0, -1)
            case 124: return (0, 1)
            default:
                break
            }
            guard let char = event.charactersIgnoringModifiers?.lowercased().first else { return nil }
            switch char {
            case "w": return (-1, 0)
            case "s": return (1, 0)
            case "a": return (0, -1)
            case "d": return (0, 1)
            default: return nil
            }
        }

        private static func isClearKey(_ event: NSEvent) -> Bool {
            isDeleteKey(event) || event.charactersIgnoringModifiers?.lowercased() == "e"
        }

        private static func isDeleteKey(_ event: NSEvent) -> Bool {
            event.keyCode == 51 || event.keyCode == 117
        }

        private static func digit(from event: NSEvent) -> Int? {
            guard let char = event.charactersIgnoringModifiers?.first,
                  let value = Int(String(char)),
                  (1...9).contains(value) else { return nil }
            return value
        }
    }
}
#endif
