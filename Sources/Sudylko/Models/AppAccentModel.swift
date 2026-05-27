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
        applyResolvedState(force: true)
        // Filter to UserDefaults.standard so writes to the dock-plugin suite from
        // `synchronizeForDockPlugin` don't bounce back into this observer and recurse.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
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
        applyResolvedState(force: false)
    }

    /// `UserDefaults.didChangeNotification` fires on any standard-defaults write, including the
    /// app's many `@AppStorage` keys. Only do the SwiftUI invalidation + cross-process mirror
    /// flush when accent/appearance actually changed; otherwise this runs on every tap and
    /// hammers `dockPluginDefaults.synchronize()` from the main thread.
    private func applyResolvedState(force: Bool) {
        let accentRaw = UserDefaults.standard.string(forKey: Keys.accent)
            ?? AppAccentColor.blue.rawValue
        let appearanceRaw = UserDefaults.standard.string(forKey: Keys.appearance)
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
        SudylkoPreferenceAccess.synchronizeForDockPlugin()
        #if os(macOS)
        DockIconRenderer.invalidateCache()
        #endif
    }
}
