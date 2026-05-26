import AppKit
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
        return blend(base, accent.color, amount: amount)
    }

    static func sidebarTint(accent: AppAccentColor, colorScheme: ColorScheme) -> Color {
        let amount: CGFloat = colorScheme == .dark ? 0.22 : 0.12
        let base = colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.09)
            : Color(red: 0.95, green: 0.95, blue: 0.94)
        return blend(base, accent.color, amount: amount)
    }

    private static func blend(_ base: Color, _ accent: Color, amount: CGFloat) -> Color {
        let nsBase = NSColor(base)
        let nsAccent = NSColor(accent)
        guard let b = nsBase.usingColorSpace(.deviceRGB),
              let a = nsAccent.usingColorSpace(.deviceRGB) else { return base }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        b.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        a.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount
        )
    }
}
