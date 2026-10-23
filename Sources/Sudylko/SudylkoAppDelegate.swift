#if os(macOS)
import AppKit
import SudylkoShared

@MainActor
final class SudylkoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        #if DEBUG
        DebugMenuController.install()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        // The Dock keeps the plug-in's last contentView between launches, so it only redraws for the final
        // values if we tell it to.
        if let appID = Bundle.main.bundleIdentifier {
            SudylkoDockDomain(appID: appID).postPreferencesDidChange()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
