#if os(iOS)
import SwiftUI

/// iOS has no Dock tile; stubs keep shared call sites compiling.
@MainActor
public enum DockIconRenderer {
    public static func updateDockIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        inGame: Bool,
        showPaused: Bool,
        timerText: String?
    ) {}
}
#endif
