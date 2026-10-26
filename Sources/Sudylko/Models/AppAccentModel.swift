import Foundation
import Observation
import SudylkoShared
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Single source of truth for the user-chosen accent and appearance; drives SwiftUI `tint` and `\.appAccent` for the
/// whole app, and on macOS `NSApp.appearance`, which every window, toolbar, menu and alert inherits.
@Observable
@MainActor
final class AppAccentModel {
    #if os(macOS)
    private let dockDomain = Bundle.main.bundleIdentifier.map(SudylkoDockDomain.init(appID:))
    @ObservationIgnored private var appliedAppAppearance: AppearanceMode?
    #endif

    /// macOS system appearance when settings use “System”; updated by `ContentView`.
    @ObservationIgnored var systemColorScheme: ColorScheme = AppearanceMode.systemColorScheme() {
        didSet { refresh() }
    }

    private(set) var accent: AppAccentColor = .blue
    private(set) var appearanceMode: AppearanceMode = .system
    private(set) var resolvedColorScheme: ColorScheme = .light
    private(set) var interactiveTint: Color = AppAccentColor.blue.color
    private(set) var prominentTint: Color = AppAccentColor.blue.color

    /// The palette `AppWindow` and `SettingsWindow` install, in the chosen accent.
    var palette: SudylkoPalette { SudylkoPalette(accent: interactiveTint) }

    init() {
        applyResolvedState(force: true)
        // The model lives as long as the app, so the observer is never removed.
        _ = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        #if os(macOS)
        // The model is made in `App.init`, before `NSApp` exists, so the appearance lands once AppKit is up and
        // before any window opens.
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.willFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyAppAppearance() }
        }
        #endif
    }

    func refresh() {
        applyResolvedState(force: false)
        #if os(macOS)
        applyAppAppearance()
        #endif
    }

    #if os(macOS)
    private func applyAppAppearance() {
        guard let app = NSApp, appliedAppAppearance != appearanceMode else { return }
        app.appearance = appearanceMode.resolvedNSAppearance()
        appliedAppAppearance = appearanceMode
    }
    #endif

    /// Skips the observation cascade when accent, appearance, and resolved scheme are unchanged.
    private func applyResolvedState(force: Bool) {
        let accentRaw = UserDefaults.standard.string(forKey: SudylkoPreferenceKey.accent)
            ?? AppAccentColor.blue.rawValue
        let appearanceRaw = UserDefaults.standard.string(forKey: SudylkoPreferenceKey.appearance)
            ?? AppearanceMode.system.rawValue

        let resolvedAccent = AppAccentColor(rawValue: accentRaw) ?? .blue
        let resolvedAppearance = AppearanceMode(rawValue: appearanceRaw) ?? .system
        let scheme = resolvedAppearance.resolvedColorScheme(system: systemColorScheme)

        if !force,
           resolvedAccent == accent,
           resolvedAppearance == appearanceMode,
           scheme == resolvedColorScheme {
            return
        }

        accent = resolvedAccent
        appearanceMode = resolvedAppearance
        resolvedColorScheme = scheme
        interactiveTint = resolvedAccent.interactiveForeground(for: scheme)
        prominentTint = resolvedAccent.displayColor(for: scheme)
        #if os(macOS)
        dockDomain?.postPreferencesDidChange()
        #endif
    }
}
