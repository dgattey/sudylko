import SwiftUI

enum ThemeMetrics {
    static let controlCornerRadius: CGFloat = 6
}

enum AppTheme {
    static func tintedBackground(accent: AppAccentColor, colorScheme: ColorScheme) -> Color {
        let amount: CGFloat = colorScheme == .dark ? 0.14 : 0.14
        let base = colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.09)
            : Color(red: 0.98, green: 0.98, blue: 0.99)
        return PlatformColor.blend(base: base, accent: accent.color, amount: amount)
    }

    static func sidebarTint(accent: AppAccentColor, colorScheme: ColorScheme) -> Color {
        let amount: CGFloat = colorScheme == .dark ? 0.22 : 0.12
        let base = colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.09)
            : Color(red: 0.95, green: 0.95, blue: 0.94)
        return PlatformColor.blend(base: base, accent: accent.color, amount: amount)
    }
}
