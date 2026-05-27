import Foundation

#if os(macOS)
public enum SudylkoDockNotifications {
    public static let preferencesDidChange = Notification.Name("com.sudylko.dockPreferencesDidChange")

    public static func postPreferencesDidChange() {
        DistributedNotificationCenter.default().post(
            name: preferencesDidChange,
            object: nil
        )
    }
}
#endif
