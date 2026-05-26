#if os(macOS)
import AppKit
import Foundation

@objc final class EditMenuDeleteController: NSObject {
    static let shared = EditMenuDeleteController()
    private static let menuItemTitle = "Delete"

    @objc func deleteSelectedCell(_ sender: Any?) {
        NotificationCenter.default.post(name: .deleteCell, object: nil)
    }

    @discardableResult
    func performDelete(from sender: Any?) -> Bool {
        deleteSelectedCell(sender)
        return true
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(deleteSelectedCell(_:)) else { return true }
        return MainActor.assumeIsolated {
            AppCommandState.live?.canDelete ?? false
        }
    }

    static func installDeleteMenuItem() {
        guard let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu else { return }
        for item in editMenu.items where item.title == menuItemTitle {
            item.target = shared
            item.action = #selector(deleteSelectedCell(_:))
            item.keyEquivalent = "\u{7F}"
        }
    }
}
#endif
