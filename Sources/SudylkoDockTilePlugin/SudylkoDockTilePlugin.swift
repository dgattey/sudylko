#if os(macOS)
import AppKit
import SudylkoShared

/// Quit-state Dock icon.
///
/// The Dock loads this bundle into a long-lived dock-extra XPC process and calls
/// `setDockTile(_:)` exactly once per plug-in lifetime. Without an extra signal, the
/// contentView the plug-in installs on that first call is what the Dock keeps showing across
/// subsequent host launches and quits, even after the host writes new accent values to the
/// shared suite. We hold the tile reference and re-apply it whenever the host posts
/// `SudylkoDockNotifications.preferencesDidChange`, so the next quit-state render reflects
/// whatever the host most recently wrote.
@objc(SudylkoDockTilePlugIn)
public final class SudylkoDockTilePlugIn: NSObject, NSDockTilePlugIn {
    private static var currentDockTile: NSDockTile?
    private static var observer: NSObjectProtocol?

    public func setDockTile(_ dockTile: NSDockTile?) {
        Self.currentDockTile = dockTile
        if let dockTile {
            Self.installPreferencesObserverIfNeeded()
            DockIconRenderer.applyQuitStateDockTile(dockTile)
        } else {
            Self.removeObserver()
        }
    }

    private static func installPreferencesObserverIfNeeded() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: SudylkoDockNotifications.preferencesDidChange,
            object: nil,
            queue: .main
        ) { _ in
            guard let tile = currentDockTile else { return }
            DockIconRenderer.applyQuitStateDockTile(tile)
        }
    }

    private static func removeObserver() {
        guard let observer else { return }
        DistributedNotificationCenter.default().removeObserver(observer)
        self.observer = nil
    }
}
#endif
