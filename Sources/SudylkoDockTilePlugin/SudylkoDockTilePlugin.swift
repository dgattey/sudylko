#if os(macOS)
import AppKit
import SudylkoShared

/// Quit-state Dock icon.
///
/// The Dock loads this bundle into a long-lived dock-extra XPC process and calls
/// `setDockTile(_:)` exactly once per plug-in lifetime. Without an extra signal, the
/// contentView the plug-in installs on that first call is what the Dock keeps showing across
/// subsequent host launches and quits, even after the appearance changes. We hold the tile
/// reference and re-apply it on two distributed notifications: the host's
/// `preferencesDidChange` (accent or appearance write, and terminate) and the OS-wide
/// `systemAppearanceDidChange`. The second is what keeps the quit-state icon following the
/// system light/dark setting while the host isn't running.
@objc(SudylkoDockTilePlugIn)
public final class SudylkoDockTilePlugIn: NSObject, NSDockTilePlugIn {
    private static var currentDockTile: NSDockTile?
    private static var observers: [NSObjectProtocol] = []

    public func setDockTile(_ dockTile: NSDockTile?) {
        Self.currentDockTile = dockTile
        if let dockTile {
            Self.installObserversIfNeeded()
            DockIconRenderer.applyQuitStateDockTile(dockTile)
        } else {
            Self.removeObservers()
        }
    }

    private static func installObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        let reapply: (Notification) -> Void = { _ in
            guard let tile = currentDockTile else { return }
            DockIconRenderer.applyQuitStateDockTile(tile)
        }
        observers = [
            SudylkoDockNotifications.preferencesDidChange,
            SudylkoDockNotifications.systemAppearanceDidChange,
        ].map { name in
            center.addObserver(forName: name, object: nil, queue: .main, using: reapply)
        }
    }

    private static func removeObservers() {
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
}
#endif
