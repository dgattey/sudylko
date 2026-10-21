#if os(macOS)
import AppKit
import SwiftUI

/// Handles Escape on screens without `BoardKeyboardHost` (e.g. home).
struct EscapeKeyboardHost: NSViewRepresentable {
    var onEscape: () -> Bool

    func makeNSView(context: Context) -> EscapeNSView {
        let view = EscapeNSView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: EscapeNSView, context: Context) {
        nsView.onEscape = onEscape
        DispatchQueue.main.async {
            if let window = nsView.window, window.firstResponder !== nsView {
                window.makeFirstResponder(nsView)
            }
        }
    }

    final class EscapeNSView: NSView {
        var onEscape: (() -> Bool)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            focusRingType = .none
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            focusRingType = .none
        }

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53, onEscape?() == true {
                return
            }
            super.keyDown(with: event)
        }
    }
}
#endif
