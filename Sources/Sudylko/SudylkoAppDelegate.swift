import AppKit

final class SudylkoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        EditMenuCleaner.disableSystemInjectedItems()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        DispatchQueue.main.async {
            EditMenuCleaner.prune()
            HelpMenuShortcutController.installHelpMenuKeyEquivalent()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        EditMenuCleaner.prune()
        HelpMenuShortcutController.installHelpMenuKeyEquivalent()
    }

    func applicationWillUpdate(_ notification: Notification) {
        DispatchQueue.main.async {
            EditMenuCleaner.prune()
            HelpMenuShortcutController.installHelpMenuKeyEquivalent()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
