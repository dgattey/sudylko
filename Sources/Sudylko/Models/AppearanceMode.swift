import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    func resolvedColorScheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: system
        }
    }

    /// `nil` for system mode so the window follows macOS instead of keeping a forced prior theme.
    func resolvedNSAppearance() -> NSAppearance? {
        switch self {
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        case .system:
            nil
        }
    }

    /// `nil` lets SwiftUI follow the window / system appearance.
    func preferredColorScheme(system: ColorScheme) -> ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    static func systemColorScheme() -> ColorScheme {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }

    static let systemThemeDidChangeNotification = Notification.Name(
        "AppleInterfaceThemeChangedNotification"
    )
}
