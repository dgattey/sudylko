import AppKit
import Foundation

enum SudylkoKeyEvent {
    static func isSpace(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49 else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return !flags.contains(.command)
            && !flags.contains(.control)
            && !flags.contains(.option)
    }

    /// Shift + / on a US QWERTY keyboard produces `?`.
    static func isShiftQuestionMark(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.shift),
              !flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control) else {
            return false
        }
        if event.keyCode == 44 { return true }
        return event.characters == "?"
    }
}

@objc final class HelpMenuShortcutController: NSObject {
    static let shared = HelpMenuShortcutController()
    private static let menuItemTitle = "Keyboard Shortcuts"

    @objc func showKeyboardShortcuts(_ sender: Any?) {
        NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
    }

    @discardableResult
    func performShortcut(from sender: Any?) -> Bool {
        showKeyboardShortcuts(sender)
        return true
    }

    static func installHelpMenuKeyEquivalent() {
        if let helpMenu = NSApp.helpMenu {
            wireShortcut(on: helpMenu.items)
        }
        if let helpMenuItem = NSApp.mainMenu?.items.first(where: { $0.title == "Help" }),
           let submenu = helpMenuItem.submenu {
            wireShortcut(on: submenu.items)
        }
    }

    private static func wireShortcut(on items: [NSMenuItem]) {
        for item in items where item.title == menuItemTitle {
            item.target = shared
            item.action = #selector(showKeyboardShortcuts(_:))
            item.keyEquivalent = "?"
            item.keyEquivalentModifierMask = .shift
        }
    }

}
