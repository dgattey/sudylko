import SwiftUI
import SudylkoShared

/// Single source of truth for the user-chosen accent; drives SwiftUI `tint` and `\.appAccent` for the whole app.
@MainActor
final class AppAccentModel: ObservableObject {
    private enum Keys {
        static let accent = "accentColor"
        static let appearance = "appearanceMode"
    }

    /// macOS system appearance when settings use “System”; updated by `ContentView`.
    var systemColorScheme: ColorScheme = AppearanceMode.systemColorScheme() {
        didSet { refresh() }
    }

    @Published private(set) var accent: AppAccentColor = .blue
    @Published private(set) var appearanceMode: AppearanceMode = .system
    @Published private(set) var resolvedColorScheme: ColorScheme = .light
    @Published private(set) var interactiveTint: Color = AppAccentColor.blue.color
    @Published private(set) var prominentTint: Color = AppAccentColor.blue.color

    private var defaultsObserver: NSObjectProtocol?

    init() {
        refresh()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func refresh() {
        let accentRaw = UserDefaults.standard.string(forKey: Keys.accent)
            ?? AppAccentColor.blue.rawValue
        let appearanceRaw = UserDefaults.standard.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue

        let resolvedAccent = AppAccentColor(rawValue: accentRaw) ?? .blue
        let resolvedAppearance = AppearanceMode(rawValue: appearanceRaw) ?? .system
        let scheme = resolvedAppearance.resolvedColorScheme(system: systemColorScheme)

        accent = resolvedAccent
        appearanceMode = resolvedAppearance
        resolvedColorScheme = scheme
        interactiveTint = resolvedAccent.interactiveForeground(for: scheme)
        prominentTint = resolvedAccent.displayColor(for: scheme)
        SudylkoPreferenceAccess.synchronizeForDockPlugin()
        #if os(macOS)
        DockIconRenderer.invalidateCache()
        SudylkoDockNotifications.postPreferencesDidChange()
        #endif
    }
}
