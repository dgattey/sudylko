#if os(iOS)
import SwiftUI

/// iOS has no Dock tile; stubs keep shared call sites compiling.
@MainActor
enum DockIconRenderer {
    static func updateDockIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        inGame: Bool,
        showPaused: Bool,
        timerText: String?
    ) {}
}
#endif
