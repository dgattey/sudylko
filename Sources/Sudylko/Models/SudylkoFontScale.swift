import SwiftUI

/// Sudylko point sizes and weights for each semantic `Font.TextStyle`. Use `.font(.headline)` only — no `.fontWeight` / weight overrides.
enum SudylkoFontScale {
    static let minimumReadablePointSize: CGFloat = 13
    static let chartAxisPointSize: CGFloat = 12
    static let compactPointSize: CGFloat = 12

    static func font(
        for textStyle: Font.TextStyle,
        design: Font.Design = .default,
        puzzleFont: PuzzleFontStyle = .rounded
    ) -> Font {
        let weight = weight(for: textStyle)
        switch textStyle {
        case .largeTitle:
            return puzzleFont.font(size: 28, weight: weight)
        case .title:
            return .system(size: 34, weight: weight, design: design)
        case .title2:
            return .system(size: 24, weight: weight, design: design)
        case .title3:
            return .system(size: 20, weight: weight, design: design)
        case .headline:
            return .system(size: 17, weight: weight, design: design)
        case .subheadline:
            return .system(size: 15, weight: weight, design: design)
        case .body:
            return .system(size: 15, weight: weight, design: design)
        case .callout:
            return .system(size: 14, weight: weight, design: design)
        case .footnote:
            return .system(size: minimumReadablePointSize, weight: weight, design: design)
        case .caption:
            return .system(size: compactPointSize, weight: weight, design: design)
        case .caption2:
            return .system(size: chartAxisPointSize, weight: weight, design: design)
        @unknown default:
            return .system(textStyle, design: design, weight: weight)
        }
    }

    /// Extra line spacing for compact styles (badges, chart labels).
    static func lineSpacing(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .caption, .caption2:
            return 5
        case .footnote:
            return 3
        case .subheadline:
            return 2
        default:
            return 0
        }
    }

    /// Vertical inset so single-line compact text does not clip in pills and labels.
    static func compactVerticalPadding(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .caption, .caption2:
            return 2
        case .footnote:
            return 1
        default:
            return 0
        }
    }

    /// Minimum layout height for compact semantic styles (line box, not point size).
    static func minimumLayoutHeight(for textStyle: Font.TextStyle) -> CGFloat? {
        switch textStyle {
        case .caption:
            return 18
        case .caption2:
            return 16
        case .footnote:
            return 18
        default:
            return nil
        }
    }

    /// Large SF Symbol sizes — weights and point sizes live here only.
    enum SymbolSize {
        case puzzleEndBanner
        case overlayHero
        case pausePlayControl
        case statsEmptyIcon
    }

    static func symbolFont(_ size: SymbolSize) -> Font {
        let pointSize: CGFloat
        let weight: Font.Weight
        switch size {
        case .puzzleEndBanner:
            pointSize = 72
            weight = .semibold
        case .overlayHero:
            pointSize = 56
            weight = .semibold
        case .pausePlayControl:
            pointSize = 36
            weight = .semibold
        case .statsEmptyIcon:
            pointSize = 28
            weight = .semibold
        }
        return .system(size: pointSize, weight: weight)
    }

    private static func weight(for textStyle: Font.TextStyle) -> Font.Weight {
        switch textStyle {
        case .largeTitle, .headline, .subheadline, .title2, .title3:
            .semibold
        case .title:
            .bold
        case .caption, .footnote:
            .semibold
        case .caption2:
            .medium
        default:
            .regular
        }
    }
}

// MARK: - Semantic scale

// | Layer | Style | Example |
// |-------|-------|---------|
// | Brand | `.largeTitle` | Sudylko, “Start a new game” (puzzle font from settings) |
// | Screen | `.title2` | Statistics, Achievements |
// | Modal | `.title`, `.title3` | Win/loss, loading overlay |
// | Section / save title | `.subheadline` | Sidebar groups, game # rows (system) |
// | Card title | `.headline` | Quick-start tiles, New game button (system) |
// | Control | `.body` | Buttons, toggles, toolbar |
// | Secondary | `.callout` | Descriptions, timers, subtitles |
// | Group label | `.footnote` | Settings section labels |
// | Compact | `.caption` | Difficulty pills, eyebrows |
// | Chart only | `.caption2` | Axis ticks |

// MARK: - Route `.font(.headline)` through the scale

private struct SudylkoTextStyleFontModifier: ViewModifier {
    @Environment(\.puzzleFontStyle) private var puzzleFont
    let textStyle: Font.TextStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = content
            .font(SudylkoFontScale.font(for: textStyle, puzzleFont: puzzleFont))
            .lineSpacing(SudylkoFontScale.lineSpacing(for: textStyle))
            .padding(.vertical, SudylkoFontScale.compactVerticalPadding(for: textStyle))

        if let minHeight = SudylkoFontScale.minimumLayoutHeight(for: textStyle) {
            base.frame(minHeight: minHeight, alignment: .center)
        } else {
            base
        }
    }
}

extension View {
    func font(_ textStyle: Font.TextStyle) -> some View {
        modifier(SudylkoTextStyleFontModifier(textStyle: textStyle))
    }

    func sudylkoSymbolFont(_ size: SudylkoFontScale.SymbolSize) -> some View {
        font(SudylkoFontScale.symbolFont(size))
    }

    func sudylkoAppTypography() -> some View {
        environment(\.font, SudylkoFontScale.font(for: .body))
    }
}
