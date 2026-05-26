import SwiftUI

private struct IsWindowFullscreenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the main window is in (or entering) AppKit fullscreen.
    var isWindowFullscreen: Bool {
        get { self[IsWindowFullscreenKey.self] }
        set { self[IsWindowFullscreenKey.self] = newValue }
    }
}
