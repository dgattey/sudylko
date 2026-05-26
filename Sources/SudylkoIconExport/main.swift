import AppKit
import Foundation
import SwiftUI
import SudylkoShared

@main
enum SudylkoIconExport {
    static func main() {
        let env = ProcessInfo.processInfo.environment
        guard let iconsetPath = env["SUDYLKO_EXPORT_ICONSET"] else {
            fputs("error: set SUDYLKO_EXPORT_ICONSET\n", stderr)
            exit(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if let maskBundle = env["SUDYLKO_ICON_MASK_BUNDLE"] {
            MacAppIconMask.maskBundlePath = maskBundle
        }

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
    }
}
