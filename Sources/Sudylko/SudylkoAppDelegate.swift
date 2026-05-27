#if os(macOS)
import AppKit
import SudylkoShared
import SwiftUI

final class SudylkoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if runIconExportIfRequested() { return }
        EditMenuCleaner.disableSystemInjectedItems()
    }

    /// Build-time icon export (`scripts/generate-app-icon.sh`) — same renderer as the live Dock tile.
    private func runIconExportIfRequested() -> Bool {
        let env = ProcessInfo.processInfo.environment
        guard let iconsetPath = env["SUDYLKO_EXPORT_ICONSET"] else { return false }

        NSApplication.shared.setActivationPolicy(.accessory)

        let raw = env["SUDYLKO_ICON_ACCENT"]
            ?? UserDefaults.standard.string(forKey: "accentColor")
            ?? AppAccentColor.blue.rawValue
        let accent = AppAccentColor(rawValue: raw) ?? .blue
        let url = URL(fileURLWithPath: iconsetPath, isDirectory: true)

        let colorScheme: ColorScheme
        if let schemeRaw = env["SUDYLKO_ICON_SCHEME"] {
            colorScheme = schemeRaw == "dark" ? .dark : .light
        } else {
            colorScheme = DockIconRenderer.resolvedDockColorScheme()
        }

        DockIconRenderer.exportIconSet(to: url, accent: accent, colorScheme: colorScheme)
        exit(0)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIconRenderer.applySavedAccentDockArtwork()
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

    func applicationWillTerminate(_ notification: Notification) {
        SudylkoPreferenceAccess.flushForTerminate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
