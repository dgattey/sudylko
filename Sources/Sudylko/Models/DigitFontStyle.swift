import SwiftUI

enum DigitFontStyle: String, CaseIterable, Identifiable {
    case rounded
    case classic
    case stencil
    case soft
    case slab
    case outline

    var id: String { rawValue }

    var previewName: String {
        switch self {
        case .rounded: "Rounded"
        case .classic: "Classic"
        case .stencil: "Stencil"
        case .soft: "Soft"
        case .slab: "Slab"
        case .outline: "Outline"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch self {
        case .rounded:
            .system(size: size, weight: weight, design: .rounded)
        case .classic:
            .system(size: size, weight: weight, design: .serif)
        case .stencil:
            .system(size: size, weight: .heavy, design: .monospaced)
        case .soft:
            .system(size: size, weight: .semibold, design: .default)
        case .slab:
            .system(size: size, weight: .black, design: .serif)
        case .outline:
            .system(size: size, weight: .ultraLight, design: .rounded)
        }
    }
}

private struct DigitFontKey: EnvironmentKey {
    static let defaultValue: DigitFontStyle = .rounded
}

extension EnvironmentValues {
    var digitFontStyle: DigitFontStyle {
        get { self[DigitFontKey.self] }
        set { self[DigitFontKey.self] = newValue }
    }
}
