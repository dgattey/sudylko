import SwiftUI

enum NumberPadStyle {
    case row
    case grid3x3
}

struct NumberPadView: View {
    @ObservedObject var game: GameViewModel
    let style: NumberPadStyle
    var maxWidth: CGFloat
    var maxHeight: CGFloat = .infinity
    var boardSide: CGFloat = 0
    var onInteraction: (() -> Void)? = nil

    @Environment(\.digitFontStyle) private var digitFontStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent

    private let spacing: CGFloat = 8
    private let noteButtonWidthUnits: CGFloat = 2

    private var keySize: CGFloat {
        switch style {
        case .row:
            return Self.keySize(for: maxWidth, style: .row, includesNote: true)
        case .grid3x3:
            let keyFromWidth = (maxWidth - spacing * 2) / 3
            let keyFromHeight = (maxHeight - spacing * 3) / 4
            let cap = boardSide > 0 ? min(80, boardSide * 0.12) : 56
            return min(cap, max(32, min(keyFromWidth, keyFromHeight)))
        }
    }

    private var gridContentWidth: CGFloat {
        keySize * 3 + spacing * 2
    }

    private var noteButtonWidth: CGFloat {
        noteButtonWidthUnits * keySize + spacing
    }

    static func keySize(for maxWidth: CGFloat, style: NumberPadStyle, includesNote: Bool = false) -> CGFloat {
        switch style {
        case .row:
            let unitCount: CGFloat = includesNote ? 12 : 10
            let totalSpacing = 8 * (unitCount - 1)
            let fit = (maxWidth - totalSpacing) / unitCount
            return min(48, max(28, fit))
        case .grid3x3:
            let spacing: CGFloat = 8
            let keyFromWidth = (maxWidth - spacing * 2) / 3
            return min(56, max(28, keyFromWidth))
        }
    }

    static func requiredHeight(
        for style: NumberPadStyle,
        maxWidth: CGFloat,
        boardSide: CGFloat = 0,
        includesNote: Bool = false
    ) -> CGFloat {
        switch style {
        case .row:
            return keySize(for: maxWidth, style: .row, includesNote: includesNote) + 18
        case .grid3x3:
            let cap = boardSide > 0 ? min(80, boardSide * 0.12) : 56
            let key = min(cap, keySize(for: maxWidth, style: .grid3x3, includesNote: includesNote))
            return key * 4 + 8 * 3 + 18
        }
    }

    static func requiredWidth(for style: NumberPadStyle, maxHeight: CGFloat, boardSide: CGFloat = 0) -> CGFloat {
        let cap = boardSide > 0 ? min(80, boardSide * 0.12) : 56
        let key = min(cap, max(32, (maxHeight - 18 - 8 * 3) / 4))
        return key * 3 + 8 * 2
    }

    var body: some View {
        switch style {
        case .row:
            rowPad
        case .grid3x3:
            gridPad
        }
    }

    private var rowPad: some View {
        HStack(spacing: spacing) {
            ForEach(1...9, id: \.self) { digit in
                digitButton(digit)
            }
            noteButton
            clearButton
        }
        .frame(
            width: maxWidth,
            height: Self.requiredHeight(for: .row, maxWidth: maxWidth, includesNote: true)
        )
    }

    private var gridPad: some View {
        VStack(spacing: spacing) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(keySize), spacing: spacing), count: 3),
                spacing: spacing
            ) {
                ForEach(1...9, id: \.self) { digit in
                    digitButton(digit)
                }
            }
            .frame(width: gridContentWidth, height: keySize * 3 + spacing * 2)

            HStack(spacing: spacing) {
                noteButton
                clearButton
            }
            .frame(width: gridContentWidth)
        }
        .frame(width: gridContentWidth)
        .frame(
            maxWidth: maxWidth,
            maxHeight: max(maxHeight, Self.requiredHeight(for: .grid3x3, maxWidth: maxWidth, boardSide: boardSide)),
            alignment: .center
        )
    }

    private func digitButton(_ digit: Int) -> some View {
        let highlighted = game.highlightedDigit == digit
        let inNoteMode = game.isPencilMode
        return Button {
            onInteraction?()
            game.highlightDigit(digit)
        } label: {
            Group {
                if inNoteMode {
                    Text("\(digit)")
                        .font(digitFontStyle.font(size: keySize * 0.28, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(5)
                } else {
                    Text("\(digit)")
                        .font(digitFontStyle.font(size: keySize * 0.45, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: keySize, height: keySize)
        .buttonStyle(.bordered)
        .tint(highlighted ? accent.interactiveForeground(for: colorScheme) : nil)
        .padKeyBorder(highlighted: highlighted, accent: accent, colorScheme: colorScheme)
        .sudylkoFocusSuppressed()
    }

    private var noteButton: some View {
        Button {
            onInteraction?()
            game.togglePencilMode()
        } label: {
            Label("Note", systemImage: "square.and.pencil")
                .font(.system(size: min(15, keySize * 0.34), weight: .semibold))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: style == .row ? noteButtonWidth : noteButtonWidth, height: keySize)
        .buttonStyle(.bordered)
        .tint(game.isPencilMode ? accent.interactiveForeground(for: colorScheme) : nil)
        .padKeyBorder(highlighted: game.isPencilMode, accent: accent, colorScheme: colorScheme)
        .sudylkoFocusSuppressed()
        .help("Notes mode — tap numbers to add small pencil marks")
    }

    private var clearButton: some View {
        Button {
            onInteraction?()
            if let selected = game.selected {
                game.clearValue(at: selected)
            }
            game.clearHighlight()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: keySize * 0.38, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: keySize, height: keySize)
        .buttonStyle(.bordered)
        .padKeyBorder(highlighted: false, accent: accent, colorScheme: colorScheme)
        .sudylkoFocusSuppressed()
        .help("Clear selected cell")
    }
}

private extension View {
    func padKeyBorder(highlighted: Bool, accent: AppAccentColor, colorScheme: ColorScheme) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    highlighted ? accent.selectionBorder(for: colorScheme) : Color.primary.opacity(0.28),
                    lineWidth: highlighted && accent.prefersStrongSelectionBorder ? 1.5 : 1
                )
        }
    }
}
