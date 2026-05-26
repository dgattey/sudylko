import SwiftUI

private struct IsAppActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether Sudylko is the active application (`NSApp.isActive`).
    var isAppActive: Bool {
        get { self[IsAppActiveKey.self] }
        set { self[IsAppActiveKey.self] = newValue }
    }
}
