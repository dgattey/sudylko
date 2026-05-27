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
        // `synchronizeIfNeeded` don't bounce back into this observer and recurse.
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

    /// Two early-outs, one per concern. The suite mirror runs on every refresh because
    /// `synchronizeIfNeeded` is cheap when standard and suite agree (two in-memory reads per
    /// mirrored key, no disk I/O) and the quit-state plug-in depends on it being current.
    /// The SwiftUI invalidation early-out is separate: skip the `@Published` cascade and the
    /// icon cache invalidation when accent, appearance, and resolved scheme are unchanged.
    private func applyResolvedState(force: Bool) {
        let accentRaw = UserDefaults.standard.string(forKey: Keys.accent)
            ?? AppAccentColor.blue.rawValue
        let appearanceRaw = UserDefaults.standard.string(forKey: Keys.appearance)
            ?? AppearanceMode.system.rawValue

        let resolvedAccent = AppAccentColor(rawValue: accentRaw) ?? .blue
        let resolvedAppearance = AppearanceMode(rawValue: appearanceRaw) ?? .system
        let scheme = resolvedAppearance.resolvedColorScheme(system: systemColorScheme)

        let suiteChanged = SudylkoPreferenceAccess.synchronizeIfNeeded()
        #if os(macOS)
        if suiteChanged {
            // Notify the dock-extra plug-in to re-render so a quit right now picks up
            // the change. The plug-in's `setDockTile` is only called once per plug-in
            // load, so without this kick the Dock keeps showing the old quit-state icon.
            SudylkoDockNotifications.postPreferencesDidChange()
        }
        #endif

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
        DockIconRenderer.invalidateCache()
        #endif
    }
}
