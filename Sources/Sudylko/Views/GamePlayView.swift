import SwiftUI

struct GamePlayView: View {
    @ObservedObject var game: GameViewModel
    @ObservedObject var timer: PuzzleTimer
    var onGoHome: () -> Void
    /// Return `true` when Escape was handled (modal, settings, etc.).
    var onEscape: () -> Bool

    @Binding var showSettings: Bool

    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isAppActive) private var isAppActive

    private var isPlayable: Bool {
        isAppActive && !timer.isPaused && !game.isPuzzleEnded
    }

    private var showPauseOverlay: Bool {
        isAppActive && timer.isPaused && timer.isRunning && !game.isPuzzleEnded
    }

    private func resumeFromOverlay() {
        guard timer.isPaused else { return }
        timer.resume()
        syncInputEnabled()
    }

    var body: some View {
        puzzleArea
            .onAppear { syncInputEnabled() }
        .onChange(of: timer.isPaused) { _, _ in syncInputEnabled() }
        .onChange(of: game.isPuzzleEnded) { _, _ in syncInputEnabled() }
        .onChange(of: isAppActive) { _, _ in syncInputEnabled() }
        .navigationTitle(game.puzzleSeed.windowTitle)
        .hiddenWindowToolbar()
    }

    private func syncInputEnabled() {
        game.isInputEnabled = isPlayable
    }

    @ViewBuilder
    private func boardWithPauseOverlay(side: CGFloat) -> some View {
        ZStack {
            BoardView(game: game, accent: accent)
                .allowsHitTesting(isPlayable)

            if showPauseOverlay {
                PausePlayOverlay(
                    accent: accent,
                    colorScheme: colorScheme,
                    onResume: resumeFromOverlay
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ThemeMetrics.controlCornerRadius,
                        style: .continuous
                    )
                )
            }
        }
        .frame(width: side, height: side)
    }

    private func resumeIfPaused() {
        guard timer.isPaused else { return }
        timer.resume()
        syncInputEnabled()
    }

    private var puzzleArea: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 20
            let spacing: CGFloat = 16
            let layout = PuzzleLayoutMetrics.compute(in: proxy.size, padding: padding, spacing: spacing)
            let padStyle: NumberPadStyle = layout.placement == .besideBoard ? .grid3x3 : .row

            Group {
                switch layout.placement {
                case .belowBoard:
                    VStack(spacing: spacing) {
                        boardWithPauseOverlay(side: layout.boardSide)
                        NumberPadView(
                            game: game,
                            style: padStyle,
                            maxWidth: layout.numberPadWidth,
                            boardSide: layout.boardSide,
                            onInteraction: resumeIfPaused
                        )
                        .allowsHitTesting(isPlayable)
                        .frame(height: layout.numberPadHeight)
                    }
                case .besideBoard:
                    HStack(alignment: .center, spacing: spacing) {
                        boardWithPauseOverlay(side: layout.boardSide)
                        NumberPadView(
                            game: game,
                            style: padStyle,
                            maxWidth: layout.numberPadWidth,
                            maxHeight: layout.numberPadHeight,
                            boardSide: layout.boardSide,
                            onInteraction: resumeIfPaused
                        )
                        .allowsHitTesting(isPlayable)
                        .frame(
                            width: layout.numberPadWidth,
                            height: layout.numberPadHeight
                        )
                    }
                }
            }
            .frame(width: layout.clusterWidth, height: layout.clusterHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(padding)
        }
        #if os(macOS)
        .background {
            BoardKeyboardHost(
                game: game,
                onTogglePause: {
                    guard timer.isRunning, !game.isPuzzleEnded else { return }
                    timer.togglePause()
                    syncInputEnabled()
                },
                onEscape: onEscape,
                onGoHome: onGoHome
            )
            .frame(width: 0, height: 0)
            .id(game.sessionRevision)
        }
        #endif
    }
}
