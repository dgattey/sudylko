import AppKit

enum EditMenuCleaner {
    private static let titlesToRemove: Set<String> = [
        "Cut",
        "Copy",
        "Paste",
        "Select All",
        "Start Dictation…",
        "Start Dictation...",
        "Emoji & Symbols",
    ]

    private static let actionsToRemove: Set<Selector> = [
        #selector(NSText.cut(_:)),
        #selector(NSText.copy(_:)),
        #selector(NSText.paste(_:)),
        #selector(NSText.selectAll(_:)),
        #selector(NSApplication.orderFrontCharacterPalette(_:)),
    ]

    static func disableSystemInjectedItems() {
        UserDefaults.standard.set(true, forKey: "NSDisabledDictationMenuItem")
        UserDefaults.standard.set(true, forKey: "NSDisabledCharacterPaletteMenuItem")
        UserDefaults.standard.register(defaults: [
            "NSAutoFillHeuristicControllerEnabled": false,
        ])
    }

    static func prune() {
        guard let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu else { return }
        for item in editMenu.items.reversed() {
            if shouldRemove(item) {
                editMenu.removeItem(item)
            }
        }
        trimTrailingSeparators(in: editMenu)
        EditMenuDeleteController.installDeleteMenuItem()
    }

    private static func shouldRemove(_ item: NSMenuItem) -> Bool {
        if item.title == "Delete" {
            return false
        }
        if titlesToRemove.contains(item.title) {
            return true
        }
        if item.title.localizedCaseInsensitiveContains("autofill") {
            return true
        }
        if let action = item.action {
            if actionsToRemove.contains(action) {
                return true
            }
            let name = NSStringFromSelector(action).lowercased()
            if name.contains("autofill") || name.contains("dictation") || name.contains("characterpalette") {
                return true
            }
        }
        if item.hasSubmenu, let submenu = item.submenu {
            for subitem in submenu.items where subitem.title.localizedCaseInsensitiveContains("autofill") {
                return true
            }
        }
        return false
    }

    private static func trimTrailingSeparators(in menu: NSMenu) {
        while let last = menu.items.last, last.isSeparatorItem {
            menu.removeItem(last)
        }
    }
}
