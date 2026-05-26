import SwiftUI

struct BoardView: View {
    @ObservedObject var game: GameViewModel
    @Environment(\.colorScheme) private var colorScheme
    var accent: AppAccentColor = .blue

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9

            ZStack {
                gridLayer(cellSize: cell, boardSide: side)
                unitPulseLayer(cellSize: cell, boardSide: side)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    @ViewBuilder
    private func gridLayer(cellSize: CGFloat, boardSide: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        let index = CellIndex(row: row, col: col)
                        CellView(
                            game: game,
                            index: index,
                            cellSize: cellSize
                        )
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                .fill(Color.clear)
        }
        .overlay {
            boardLines(boardSide: boardSide)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                .strokeBorder(outerBorderColor, lineWidth: 3)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous))
    }

    private var outerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.82)
    }

    @ViewBuilder
    private func unitPulseLayer(cellSize: CGFloat, boardSide: CGFloat) -> some View {
        ZStack {
            ForEach(Array(game.pulseRows), id: \.self) { row in
                pulseBand(
                    x: 0,
                    y: CGFloat(row) * cellSize,
                    width: boardSide,
                    height: cellSize
                )
            }
            ForEach(Array(game.pulseCols), id: \.self) { col in
                pulseBand(
                    x: CGFloat(col) * cellSize,
                    y: 0,
                    width: cellSize,
                    height: boardSide
                )
            }
            ForEach(Array(game.pulseBoxes), id: \.self) { box in
                let row = (box / 3) * 3
                let col = (box % 3) * 3
                pulseBand(
                    x: CGFloat(col) * cellSize,
                    y: CGFloat(row) * cellSize,
                    width: cellSize * 3,
                    height: cellSize * 3
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func pulseBand(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.accentColor.opacity(0.28))
            .frame(width: width, height: height)
            .scaleEffect(1.04)
            .opacity(0.9)
            .position(x: x + width / 2, y: y + height / 2)
            .animation(.easeOut(duration: 0.55), value: game.pulseRows.count + game.pulseCols.count + game.pulseBoxes.count)
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
