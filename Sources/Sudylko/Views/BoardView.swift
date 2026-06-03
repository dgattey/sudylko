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
                PuzzleCompletePulseOverlay(
                    generation: game.puzzleCompletePulseGeneration,
                    boardSide: side,
                    accent: accent,
                    colorScheme: colorScheme
                )
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
                UnitCompletionPulseBand(
                    x: 0,
                    y: CGFloat(row) * cellSize,
                    width: boardSide,
                    height: cellSize,
                    accent: accent,
                    colorScheme: colorScheme
                )
            }
            ForEach(Array(game.pulseCols), id: \.self) { col in
                UnitCompletionPulseBand(
                    x: CGFloat(col) * cellSize,
                    y: 0,
                    width: cellSize,
                    height: boardSide,
                    accent: accent,
                    colorScheme: colorScheme
                )
            }
            ForEach(Array(game.pulseBoxes), id: \.self) { box in
                let row = (box / 3) * 3
                let col = (box % 3) * 3
                UnitCompletionPulseBand(
                    x: CGFloat(col) * cellSize,
                    y: CGFloat(row) * cellSize,
                    width: cellSize * 3,
                    height: cellSize * 3,
                    accent: accent,
                    colorScheme: colorScheme
                )
            }
            ForEach(Array(game.pulseDigits).sorted(), id: \.self) { digit in
                ForEach(game.solutionIndices(for: digit), id: \.self) { index in
                    UnitCompletionPulseBand(
                        x: CGFloat(index.col) * cellSize,
                        y: CGFloat(index.row) * cellSize,
                        width: cellSize,
                        height: cellSize,
                        accent: accent,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .allowsHitTesting(false)
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

// MARK: - Completion pulse animations

private enum BoardPulseAnimation {
    static let ringCount = 2
    static let waveDuration = 0.72
    static let ringDuration = 0.78
    static let ringStagger = 0.14
    static let clearAfterNanoseconds: UInt64 = 920_000_000

    struct Style {
        var cornerRadius: CGFloat
        var fillOpacity: Double
        var ringStrokeOpacity: Double
        var ringLineWidth: CGFloat
        var waveStartScale: CGFloat
        var waveEndScale: CGFloat
        var waveStartOpacity: Double
        var ringStartScale: CGFloat
        var ringEndScale: CGFloat
        var ringStartOpacity: Double
    }

    static let puzzleComplete = Style(
        cornerRadius: ThemeMetrics.controlCornerRadius,
        fillOpacity: 0.24,
        ringStrokeOpacity: 0.5,
        ringLineWidth: 3,
        waveStartScale: 0.9,
        waveEndScale: 1.08,
        waveStartOpacity: 0.55,
        ringStartScale: 0.86,
        ringEndScale: 1.14,
        ringStartOpacity: 0.6
    )

    static func unitStyle(width: CGFloat, height: CGFloat) -> Style {
        let isBox = abs(width - height) < 1
        let shortSide = min(width, height)
        return Style(
            cornerRadius: isBox ? 8 : min(4, shortSide * 0.2),
            fillOpacity: 0.26,
            ringStrokeOpacity: 0.48,
            ringLineWidth: isBox ? 2.5 : 2,
            waveStartScale: 0.92,
            waveEndScale: 1.06,
            waveStartOpacity: 0.52,
            ringStartScale: 0.88,
            ringEndScale: 1.12,
            ringStartOpacity: 0.58
        )
    }
}

private struct CompletionPulseRipple: View {
    let width: CGFloat
    let height: CGFloat
    let style: BoardPulseAnimation.Style
    let pulseColor: Color
    let centerX: CGFloat
    let centerY: CGFloat
    var animationGeneration: UInt = 0
    var playOnAppear: Bool = false

    @State private var waveScale: CGFloat = 1
    @State private var waveOpacity: Double = 0
    @State private var ringScales: [CGFloat]
    @State private var ringOpacities: [Double]

    init(
        width: CGFloat,
        height: CGFloat,
        style: BoardPulseAnimation.Style,
        pulseColor: Color,
        centerX: CGFloat,
        centerY: CGFloat,
        animationGeneration: UInt = 0,
        playOnAppear: Bool = false
    ) {
        self.width = width
        self.height = height
        self.style = style
        self.pulseColor = pulseColor
        self.centerX = centerX
        self.centerY = centerY
        self.animationGeneration = animationGeneration
        self.playOnAppear = playOnAppear
        _ringScales = State(initialValue: Array(repeating: CGFloat(1), count: BoardPulseAnimation.ringCount))
        _ringOpacities = State(initialValue: Array(repeating: Double(0), count: BoardPulseAnimation.ringCount))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(pulseColor.opacity(style.fillOpacity))
                .frame(width: width, height: height)
                .scaleEffect(waveScale)
                .opacity(waveOpacity)

            ForEach(0..<ringScales.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .strokeBorder(pulseColor.opacity(style.ringStrokeOpacity), lineWidth: style.ringLineWidth)
                    .frame(width: width, height: height)
                    .scaleEffect(ringScales[index])
                    .opacity(ringOpacities[index])
            }
        }
        .position(x: centerX, y: centerY)
        .onAppear {
            if playOnAppear { runPulse() }
        }
        .onChange(of: animationGeneration) { old, new in
            guard !playOnAppear else { return }
            guard new != old, new > 0 else { return }
            runPulse()
        }
    }

    private func runPulse() {
        waveScale = style.waveStartScale
        waveOpacity = style.waveStartOpacity
        ringScales = Array(repeating: style.ringStartScale, count: BoardPulseAnimation.ringCount)
        ringOpacities = Array(repeating: style.ringStartOpacity, count: BoardPulseAnimation.ringCount)

        withAnimation(.easeOut(duration: BoardPulseAnimation.waveDuration)) {
            waveScale = style.waveEndScale
            waveOpacity = 0
        }

        for index in ringScales.indices {
            withAnimation(
                .easeOut(duration: BoardPulseAnimation.ringDuration)
                    .delay(BoardPulseAnimation.ringStagger * Double(index))
            ) {
                ringScales[index] = style.ringEndScale
                ringOpacities[index] = 0
            }
        }
    }
}

private struct UnitCompletionPulseBand: View {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    var accent: AppAccentColor
    var colorScheme: ColorScheme

    private var pulseColor: Color {
        accent.interactiveForeground(for: colorScheme)
    }

    var body: some View {
        CompletionPulseRipple(
            width: width,
            height: height,
            style: BoardPulseAnimation.unitStyle(width: width, height: height),
            pulseColor: pulseColor,
            centerX: x + width / 2,
            centerY: y + height / 2,
            playOnAppear: true
        )
    }
}

private struct PuzzleCompletePulseOverlay: View {
    let generation: UInt
    let boardSide: CGFloat
    var accent: AppAccentColor
    var colorScheme: ColorScheme

    private var pulseColor: Color {
        accent.interactiveForeground(for: colorScheme)
    }

    var body: some View {
        CompletionPulseRipple(
            width: boardSide,
            height: boardSide,
            style: BoardPulseAnimation.puzzleComplete,
            pulseColor: pulseColor,
            centerX: boardSide / 2,
            centerY: boardSide / 2,
            animationGeneration: generation
        )
        .allowsHitTesting(false)
    }
}
