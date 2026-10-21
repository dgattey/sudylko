#if os(macOS)
import AppKit
import SudylkoShared
import SwiftUI

final class SudylkoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if runIconExportIfRequested() { return }
        disableSystemInjectedEditMenuItems()
    }

    /// AppKit appends Start Dictation and Emoji & Symbols to any menu titled Edit, and SwiftUI
    /// `commands` cannot remove them. These defaults keys stop AppKit from adding them; the
    /// AutoFill key turns off text-field AutoFill heuristics.
    private func disableSystemInjectedEditMenuItems() {
        UserDefaults.standard.set(true, forKey: "NSDisabledDictationMenuItem")
        UserDefaults.standard.set(true, forKey: "NSDisabledCharacterPaletteMenuItem")
        UserDefaults.standard.register(defaults: [
            "NSAutoFillHeuristicControllerEnabled": false,
        ])
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
        #if DEBUG
        DispatchQueue.main.async {
            DebugMenuController.install()
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        SudylkoPreferenceAccess.flushForTerminate()
        // The Dock keeps the plug-in's cached contentView between launches, so kick it to
        // re-render against the suite values we just flushed.
        SudylkoDockNotifications.postPreferencesDidChange()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
