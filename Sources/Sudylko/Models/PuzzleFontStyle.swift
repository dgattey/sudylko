import SwiftUI

/// Typeface for puzzle numbers and brand `.largeTitle` text (settings → Puzzle font).
enum PuzzleFontStyle: String, CaseIterable, Identifiable {
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
            .system(size: size, weight: weight, design: .default)
        case .slab:
            .system(size: size, weight: .black, design: .serif)
        case .outline:
            .system(size: size, weight: .ultraLight, design: .rounded)
        }
    }
}

private struct PuzzleFontKey: EnvironmentKey {
    static let defaultValue: PuzzleFontStyle = .rounded
}

extension EnvironmentValues {
    var puzzleFontStyle: PuzzleFontStyle {
        get { self[PuzzleFontKey.self] }
        set { self[PuzzleFontKey.self] = newValue }
    }
}
