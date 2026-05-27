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

    /// Host side: mirror the keys we care about into the suite when (and only when) the suite
    /// disagrees with `UserDefaults.standard`. Safe to call on every refresh tick because the
    /// check is two in-memory reads per key and skips disk I/O when nothing moved. Must only
    /// be called from the host process; from inside the Dock process `UserDefaults.standard`
    /// is Dock's own preferences and the loop would clobber the mirror with `nil` for every
    /// key.
    @discardableResult
    public static func synchronizeIfNeeded() -> Bool {
        #if os(macOS)
        let standard = UserDefaults.standard
        var didWrite = false
        for key in mirroredKeys {
            let standardValue = standard.string(forKey: key)
            let suiteValue = dockPluginDefaults.string(forKey: key)
            guard standardValue != suiteValue else { continue }
            if let standardValue {
                dockPluginDefaults.set(standardValue, forKey: key)
            } else {
                dockPluginDefaults.removeObject(forKey: key)
            }
            didWrite = true
        }
        if didWrite {
            dockPluginDefaults.synchronize()
        }
        return didWrite
        #else
        return false
        #endif
    }

    /// Force a flush regardless of the diff. Used at `applicationWillTerminate` so any pending
    /// in-memory writes hit disk before the process exits and the plug-in fires.
    public static func flushForTerminate() {
        #if os(macOS)
        _ = synchronizeIfNeeded()
        dockPluginDefaults.synchronize()
        #endif
    }
}
