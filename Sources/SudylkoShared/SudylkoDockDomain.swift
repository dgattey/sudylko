#if os(macOS)
import Foundation

/// The app's preferences domain and the signal that tells its quit-state Dock tile to redraw, both named from the
/// app's bundle identifier so a dev build (`<id>.dev`) never reads or signals the installed release's.
public struct SudylkoDockDomain: Sendable {
    private static let plugInSuffix = ".docktile"

    public let appID: String

    public init(appID: String) {
        self.appID = appID
    }

    /// The plug-in's bundle identifier is the app's plus `.docktile`.
    public init?(plugInBundle: Bundle) {
        guard let identifier = plugInBundle.bundleIdentifier, identifier.hasSuffix(Self.plugInSuffix) else {
            return nil
        }
        self.init(appID: String(identifier.dropLast(Self.plugInSuffix.count)))
    }

    public var preferencesDidChange: Notification.Name {
        Notification.Name("\(appID).dockPreferencesDidChange")
    }

    public func postPreferencesDidChange() {
        DistributedNotificationCenter.default().post(name: preferencesDidChange, object: nil)
    }

    /// Synchronizes first because the Dock process otherwise keeps serving its cached copy of the app's domain.
    func string(forKey key: String) -> String? {
        CFPreferencesAppSynchronize(appID as CFString)
        return CFPreferencesCopyAppValue(key as CFString, appID as CFString) as? String
    }
}
#endif
