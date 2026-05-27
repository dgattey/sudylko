import Foundation

/// Cross-process bridge for the quit-state `NSDockTilePlugIn`.
///
/// Direction is one-way: the host app *writes* into a dedicated suite (the "mirror"); the plug-in,
/// which runs inside the Dock process where `UserDefaults.standard` would point at Dock's own
/// preferences, only *reads* from that suite. Two separate entry points enforce the direction so
/// the plug-in can't accidentally invoke the host-side write path and erase the mirror.
public enum SudylkoPreferenceAccess {
    private static let mirroredKeys = ["accentColor", "appearanceMode"]

    #if os(macOS)
    private static let dockPluginSuiteName = "com.sudylko.mac.dock"
    private static let dockPluginDefaults = UserDefaults(suiteName: dockPluginSuiteName) ?? .standard
    #endif

    /// Plug-in side: read a mirrored key. Returns `nil` until the host has populated the mirror at
    /// least once.
    public static func string(forKey key: String) -> String? {
        #if os(macOS)
        dockPluginDefaults.string(forKey: key)
        #else
        nil
        #endif
    }

    /// Plug-in side: refresh the in-memory cache from disk before reading, so updates the host
    /// flushed before quitting are visible.
    public static func refreshDockPluginCache() {
        #if os(macOS)
        dockPluginDefaults.synchronize()
        #endif
    }

    /// Host side: copy the current values of the mirrored keys from the host app's standard
    /// defaults into the mirror suite and flush to disk. Must only be called from the host
    /// process; from inside the Dock process `UserDefaults.standard` is Dock's own preferences
    /// and the loop would clobber the mirror with `nil` for every key.
    public static func synchronizeForDockPlugin() {
        #if os(macOS)
        let standard = UserDefaults.standard
        for key in mirroredKeys {
            if let value = standard.string(forKey: key) {
                dockPluginDefaults.set(value, forKey: key)
            } else {
                dockPluginDefaults.removeObject(forKey: key)
            }
        }
        dockPluginDefaults.synchronize()
        #endif
    }
}
