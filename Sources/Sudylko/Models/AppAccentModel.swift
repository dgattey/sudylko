import Foundation
import Observation
import SudylkoShared
import SwiftUI

/// Single source of truth for the user-chosen accent; drives SwiftUI `tint` and `\.appAccent` for the whole app.
@Observable
@MainActor
final class AppAccentModel {
    #if os(macOS)
    private let dockDomain = Bundle.main.bundleIdentifier.map(SudylkoDockDomain.init(appID:))
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
    }

    func refresh() {
        applyResolvedState(force: false)
    }

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
