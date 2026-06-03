import SwiftUI

struct CellView: View {
    @ObservedObject var game: GameViewModel
    let index: CellIndex
    let cellSize: CGFloat
    @Environment(\.puzzleFontStyle) private var puzzleFontStyle
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isAppActive) private var isAppActive
    @AppStorage("hideNumbersWhenInactive") private var hideNumbersWhenInactive = true

    private var showsCellContent: Bool {
        isAppActive || !hideNumbersWhenInactive
    }

    private var accentColor: Color { accent.interactiveForeground(for: colorScheme) }

    private var value: Int? {
        game.values[index.row][index.col]
    }

    private var cellNotes: Set<Int> {
        game.notes[index.row][index.col]
    }

    private var isSelected: Bool {
        game.selected == index
    }

    private var isHighlightedDigit: Bool {
        guard let digit = game.highlightedDigit else { return false }
        if value == digit { return true }
        return cellNotes.contains(digit)
    }

    private var isSameRowOrColOrBox: Bool {
        guard let selected = game.selected, selected != index else { return false }
        if selected.row == index.row || selected.col == index.col { return true }
        return game.boxIndex(row: selected.row, col: selected.col)
            == game.boxIndex(row: index.row, col: index.col)
    }

    private var isMistake: Bool {
        game.mistakeCells.contains(index)
    }

    var body: some View {
        ZStack {
            backgroundLayer
            if showsCellContent {
                if let value {
                    Text("\(value)")
                        .font(puzzleFontStyle.font(
                            size: cellSize * 0.52,
                            weight: game.isGiven(index) ? .bold : .semibold
                        ))
                        .foregroundStyle(foregroundColor)
                } else if !cellNotes.isEmpty {
                    notesGrid
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsCellContent)
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle())
        .onTapGesture {
            game.select(index)
        }
    }

    private var notesGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: cols, spacing: 0) {
            ForEach(1...9, id: \.self) { digit in
                Text(cellNotes.contains(digit) ? "\(digit)" : " ")
                    .font(puzzleFontStyle.font(size: cellSize * 0.2, weight: .medium))
                    .foregroundStyle(
                        game.highlightedDigit == digit
                            ? accentColor
                            : Color.secondary
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(cellSize * 0.08)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        Rectangle()
            .fill(backgroundColor)
    }

    private var mistakeBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.55, green: 0.18, blue: 0.20)
        }
        return Color(red: 0.90, green: 0.22, blue: 0.22)
    }

    private var mistakeForeground: Color {
        if colorScheme == .dark {
            return Color(red: 0.96, green: 0.82, blue: 0.82)
        }
        return .white
    }

    private var backgroundColor: Color {
        if isMistake {
            return mistakeBackground
        }
        if isSelected {
            return accentColor.opacity(0.38)
        }
        if isHighlightedDigit {
            return accentColor.opacity(0.24)
        }
        if isSameRowOrColOrBox {
            return accentColor.opacity(0.1)
        }
        return accent.color.opacity(0.045)
    }

    private var foregroundColor: Color {
        if isMistake {
            return mistakeForeground
        }
        if game.isGiven(index) {
            return .primary
        }
        return accentColor
    }
}
