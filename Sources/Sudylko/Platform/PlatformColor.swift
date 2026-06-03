import SwiftUI

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum PlatformColor {
    static func systemColorScheme() -> ColorScheme {
        #if os(macOS)
        // Prefer the game window’s effective appearance — NSApp can lag after we clear a forced theme.
        let appearance = NSApp.keyWindow?.effectiveAppearance
            ?? NSApp.mainWindow?.effectiveAppearance
            ?? NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
        #elseif canImport(UIKit)
        switch UITraitCollection.current.userInterfaceStyle {
        case .dark: return .dark
        case .light: return .light
        default: return .light
        }
        #else
        return .light
        #endif
    }

    static func blend(base: Color, accent: Color, amount: CGFloat) -> Color {
        #if canImport(AppKit)
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
        #elseif canImport(UIKit)
        let nsBase = UIColor(base)
        let nsAccent = UIColor(accent)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard nsBase.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              nsAccent.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return base }
        return Color(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount
        )
        #else
        return base
        #endif
    }
}
