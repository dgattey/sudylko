import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Window backdrop materials for glass panels.
/// `displayOrder` runs solid (0%) → translucent glass (100%).
enum WindowBackgroundMaterial: String, Identifiable {
    case solid
    case soft
    case standard
    case translucent
    case light
    case hud

    var id: String { rawValue }

    static let displayOrder: [WindowBackgroundMaterial] = [
        .solid, .soft, .standard, .translucent, .light, .hud,
    ]

    static var `default`: Self { .translucent }

    /// Fixed window transparency while fullscreen on macOS (slider still applies when not fullscreen).
    static let fullscreenTransparencyPercent = 20

    var transparencyPercent: Int {
        let index = Self.displayOrder.firstIndex(of: self) ?? 0
        let last = max(1, Self.displayOrder.count - 1)
        return Int((Double(index) / Double(last)) * 100)
    }

    static func material(forTransparencyPercent percent: Int) -> WindowBackgroundMaterial {
        let clamped = min(100, max(0, percent))
        let last = max(1, displayOrder.count - 1)
        let index = Int((Double(clamped) / 100.0 * Double(last)).rounded())
        return displayOrder[min(max(0, index), last)]
    }

    private static var fullscreenOverride: Self {
        material(forTransparencyPercent: fullscreenTransparencyPercent)
    }

    func effective(whenFullscreen isFullscreen: Bool) -> Self {
        #if os(macOS)
        return isFullscreen ? Self.fullscreenOverride : self
        #else
        _ = isFullscreen
        return self
        #endif
    }

    /// SwiftUI material for glass on iOS and fallback surfaces.
    var swiftUIMaterial: Material {
        switch self {
        case .solid: .regularMaterial
        case .soft: .thinMaterial
        case .standard: .regularMaterial
        case .translucent: .ultraThinMaterial
        case .light: .thinMaterial
        case .hud: .thickMaterial
        }
    }

    #if os(macOS)
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .solid: .windowBackground
        case .soft: .contentBackground
        case .standard: .underWindowBackground
        case .translucent: .menu
        case .light: .popover
        case .hud: .hudWindow
        }
    }
    #endif
}
