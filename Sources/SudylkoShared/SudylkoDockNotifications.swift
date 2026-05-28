import Foundation

#if os(macOS)
/// Cross-process kick to the quit-state plug-in.
///
/// `NSDockTilePlugIn.setDockTile(_:)` is called once per plug-in load (per dock-extra process
/// lifetime), not on every app quit. Without an additional signal, the cached contentView in
/// the Dock keeps showing whatever the plug-in rendered on its first run, even after the host
/// updates the suite. The host posts this notification whenever the dock-plugin suite changes
/// or at terminate; the plug-in's observer re-applies the dock tile with the latest suite
/// values.
public enum SudylkoDockNotifications {
    public static let preferencesDidChange = Notification.Name("com.sudylko.dockPreferencesDidChange")

    /// macOS posts this system-wide whenever the user flips light/dark (including the auto
    /// schedule). The quit-state plug-in observes it so a theme change while the host is quit
    /// re-renders the dock tile; without it the Dock keeps the appearance from the last render.
    public static let systemAppearanceDidChange = Notification.Name("AppleInterfaceThemeChangedNotification")

    public static func postPreferencesDidChange() {
        DistributedNotificationCenter.default().post(
            name: preferencesDidChange,
            object: nil
        )
    }
}
#endif
