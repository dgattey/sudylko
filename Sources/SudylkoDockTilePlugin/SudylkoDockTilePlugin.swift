#if os(macOS)
import AppKit
import SudylkoShared

/// Quit-state Dock icon. The Dock loads this bundle when Sudylko is not running and calls
/// `setDockTile(_:)`; the same `DockIconRenderer` path the running app uses produces the bitmap,
/// so the two states render the same artwork.
@objc(SudylkoDockTilePlugIn)
public final class SudylkoDockTilePlugIn: NSObject, NSDockTilePlugIn {
    public func setDockTile(_ dockTile: NSDockTile?) {
        guard let dockTile else { return }
        DockIconRenderer.applyQuitStateDockTile(dockTile)
    }
}
#endif
