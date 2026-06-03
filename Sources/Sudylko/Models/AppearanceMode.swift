import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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

    #if os(macOS)
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
    #endif

    static func systemColorScheme() -> ColorScheme {
        PlatformColor.systemColorScheme()
    }

    static let systemThemeDidChangeNotification = Notification.Name(
        "AppleInterfaceThemeChangedNotification"
    )
}
