import DylCore
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
    /// The app-wide `NSApp.appearance`. System mode is `nil`, so AppKit follows macOS live, unless devkit's
    /// `--appearance` stands in for the system appearance.
    @MainActor
    func resolvedNSAppearance() -> NSAppearance? {
        switch self {
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        case .system:
            LaunchOverrides.current.appearance.flatMap { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua) }
        }
    }
    #endif

    /// devkit's `--appearance` stands in for the system appearance, so captures of a fresh dev build follow it.
    @MainActor
    static func systemColorScheme() -> ColorScheme {
        if let forced = LaunchOverrides.current.appearance {
            return forced == .dark ? .dark : .light
        }
        return PlatformColor.systemColorScheme()
    }

    static let systemThemeDidChangeNotification = Notification.Name(
        "AppleInterfaceThemeChangedNotification"
    )
}
