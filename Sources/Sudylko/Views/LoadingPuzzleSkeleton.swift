import SwiftUI

/// Shown while a puzzle loads. Mirrors `GamePlayView`'s layout with an empty board and empty
/// number-pad keys so the spinner sits in the center of the grid (not the whole detail pane).
struct LoadingPuzzleSkeleton: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    private let padding: CGFloat = 20
    private let spacing: CGFloat = 16
    private let keySpacing: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let layout = PuzzleLayoutMetrics.compute(in: proxy.size, padding: padding, spacing: spacing)
            let padStyle: NumberPadStyle = layout.placement == .besideBoard ? .grid3x3 : .row

            Group {
                switch layout.placement {
                case .belowBoard:
                    VStack(spacing: spacing) {
                        board(side: layout.boardSide)
                        padPlaceholder(style: padStyle, layout: layout)
                            .frame(width: layout.numberPadWidth, height: layout.numberPadHeight)
                    }
                case .besideBoard:
                    HStack(alignment: .center, spacing: spacing) {
                        board(side: layout.boardSide)
                        padPlaceholder(style: padStyle, layout: layout)
                            .frame(width: layout.numberPadWidth, height: layout.numberPadHeight)
                    }
                }
            }
            .frame(width: layout.clusterWidth, height: layout.clusterHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(padding)
        }
        .accessibilityElement()
        .accessibilityLabel("Loading puzzle")
    }

    private func board(side: CGFloat) -> some View {
        EmptyBoardGrid(colorScheme: colorScheme)
            .frame(width: side, height: side)
            .overlay {
                ProgressView()
                    .controlSize(.large)
            }
    }

    // MARK: - Number pad placeholders

    @ViewBuilder
    private func padPlaceholder(style: NumberPadStyle, layout: PuzzleLayoutMetrics) -> some View {
        switch style {
        case .row:
            rowPlaceholder(maxWidth: layout.numberPadWidth)
        case .grid3x3:
            gridPlaceholder(layout: layout)
        }
    }

    private func rowPlaceholder(maxWidth: CGFloat) -> some View {
        let key = NumberPadView.keySize(for: maxWidth, style: .row, includesNote: true)
        return HStack(spacing: keySpacing) {
            ForEach(0..<9, id: \.self) { _ in keyPlaceholder(width: key, height: key) }
            keyPlaceholder(width: key * 2 + keySpacing, height: key)
            keyPlaceholder(width: key, height: key)
        }
        .frame(maxWidth: maxWidth)
    }

    private func gridPlaceholder(layout: PuzzleLayoutMetrics) -> some View {
        let keyFromWidth = (layout.numberPadWidth - keySpacing * 2) / 3
        let keyFromHeight = (layout.numberPadHeight - keySpacing * 3) / 4
        let cap = layout.boardSide > 0 ? min(80, layout.boardSide * 0.12) : 56
        let key = min(cap, max(32, min(keyFromWidth, keyFromHeight)))
        let gridWidth = key * 3 + keySpacing * 2

        return VStack(spacing: keySpacing) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(key), spacing: keySpacing), count: 3),
                spacing: keySpacing
            ) {
                ForEach(0..<9, id: \.self) { _ in keyPlaceholder(width: key, height: key) }
            }
            .frame(width: gridWidth, height: key * 3 + keySpacing * 2)

            HStack(spacing: keySpacing) {
                keyPlaceholder(width: key * 2 + keySpacing, height: key)
                keyPlaceholder(width: key, height: key)
            }
            .frame(width: gridWidth)
        }
        .frame(width: gridWidth)
    }

    private func keyPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
            .overlay {
                RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
            }
            .frame(width: width, height: height)
    }
}

/// Empty 9×9 board chrome (grid lines + outer border) matching `BoardView`, with no cell content.
private struct EmptyBoardGrid: View {
    let colorScheme: ColorScheme

    private var outerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.82)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            boardLines(boardSide: side)
                .overlay {
                    RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                        .strokeBorder(outerBorderColor, lineWidth: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous))
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func boardLines(boardSide: CGFloat) -> some View {
        Canvas { context, size in
            let cell = size.width / 9
            let thinColor = colorScheme == .dark
                ? Color.white.opacity(0.42)
                : Color.black.opacity(0.38)
            let thickColor = colorScheme == .dark
                ? Color.white.opacity(0.92)
                : Color.black.opacity(0.88)

            for i in 0...9 {
                let offset = CGFloat(i) * cell
                let isBoxLine = i % 3 == 0
                let lineWidth: CGFloat = isBoxLine ? 2.5 : 1
                let color = isBoxLine ? thickColor : thinColor

                var vertical = Path()
                vertical.move(to: CGPoint(x: offset, y: 0))
                vertical.addLine(to: CGPoint(x: offset, y: size.height))
                context.stroke(vertical, with: .color(color), lineWidth: lineWidth)

                var horizontal = Path()
                horizontal.move(to: CGPoint(x: 0, y: offset))
                horizontal.addLine(to: CGPoint(x: size.width, y: offset))
                context.stroke(horizontal, with: .color(color), lineWidth: lineWidth)
            }
        }
        .frame(width: boardSide, height: boardSide)
    }
}
