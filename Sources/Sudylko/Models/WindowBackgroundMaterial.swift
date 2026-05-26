import AppKit

/// Window backdrop materials for `VisualEffectBackground` (`.behindWindow`).
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

    var transparencyPercent: Int {
        let index = Self.displayOrder.firstIndex(of: self) ?? 0
        let last = max(1, Self.displayOrder.count - 1)
        return Int((Double(index) / Double(last)) * 100)
    }

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

}
