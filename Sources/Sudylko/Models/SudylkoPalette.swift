import DylUI
import SudylkoShared
import SwiftUI

/// DylUI's palette in the player's accent, already resolved for the app's appearance setting by `AppAccentModel`.
struct SudylkoPalette: ThemePalette {
    var accent: Color

    init() {
        self.init(accent: AppAccentColor.blue.color)
    }

    init(accent: Color) {
        self.accent = accent
    }
}
