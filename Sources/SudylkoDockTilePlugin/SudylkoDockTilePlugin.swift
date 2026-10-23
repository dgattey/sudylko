#if os(macOS)
import AppKit
import SudylkoShared

/// Quit-state Dock icon.
///
/// The Dock loads this bundle into a long-lived dock-extra XPC process and calls `setDockTile(_:)` exactly once per
/// plug-in lifetime. Without an extra signal, the contentView the plug-in installs on that first call is what the Dock
/// keeps showing across subsequent host launches and quits, even after the appearance changes. We hold the tile
/// reference and re-apply it on two distributed notifications: the host's `preferencesDidChange` (accent or
/// appearance write, and terminate) and the OS-wide `AppleInterfaceThemeChangedNotification`. The second is what
/// keeps the quit-state icon following the system light/dark setting while the host isn't running.
@objc(SudylkoDockTilePlugIn)
public final class SudylkoDockTilePlugIn: NSObject, NSDockTilePlugIn {
    private static var currentDockTile: NSDockTile?
    private static var observers: [NSObjectProtocol] = []

    public func setDockTile(_ dockTile: NSDockTile?) {
        guard let domain = SudylkoDockDomain(plugInBundle: Bundle(for: SudylkoDockTilePlugIn.self)) else { return }
        Self.currentDockTile = dockTile
        if let dockTile {
            Self.installObserversIfNeeded(domain: domain)
            Self.apply(dockTile, domain: domain)
        } else {
            Self.removeObservers()
        }
    }

    private static func installObserversIfNeeded(domain: SudylkoDockDomain) {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        let names = [domain.preferencesDidChange, Notification.Name("AppleInterfaceThemeChangedNotification")]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                guard let tile = currentDockTile else { return }
                apply(tile, domain: domain)
            }
        }
    }

    /// The Dock's calling thread is unknown, so hop to the main actor instead of assuming it.
    private static func apply(_ dockTile: NSDockTile, domain: SudylkoDockDomain) {
        Task { @MainActor in DockIconRenderer.applyQuitStateDockTile(dockTile, domain: domain) }
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
