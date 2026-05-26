import SwiftUI

enum NumberPadPlacement {
    case belowBoard
    case besideBoard
}

struct PuzzleLayoutMetrics {
    let boardSide: CGFloat
    let placement: NumberPadPlacement
    let numberPadWidth: CGFloat
    let numberPadHeight: CGFloat
    let clusterWidth: CGFloat
    let clusterHeight: CGFloat

    /// Wide detail areas use a 3×3 pad beside the board; tall areas use a row under the board.
    static func compute(in size: CGSize, padding: CGFloat = 20, spacing: CGFloat = 16) -> PuzzleLayoutMetrics {
        let contentWidth = max(0, size.width - padding * 2)
        let contentHeight = max(0, size.height - padding * 2)

        let besidePadWidth = NumberPadView.requiredWidth(for: .grid3x3, maxHeight: 480, boardSide: min(contentHeight, 900))
        let wideEnough = contentWidth >= 200 + spacing + besidePadWidth
        let isTall = contentHeight > contentWidth
        let useBeside = wideEnough && !isTall

        if useBeside {
            return metricsBeside(
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                spacing: spacing,
                padWidth: besidePadWidth
            )
        }
        return metricsStacked(
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            spacing: spacing
        )
    }

    private static func metricsStacked(
        contentWidth: CGFloat,
        contentHeight: CGFloat,
        spacing: CGFloat
    ) -> PuzzleLayoutMetrics {
        var board = min(contentWidth, 900)
        let rowPadWidth = board
        var padH = NumberPadView.requiredHeight(for: .row, maxWidth: rowPadWidth, includesNote: true)
        board = min(board, max(140, contentHeight - spacing - padH), 900)
        padH = NumberPadView.requiredHeight(for: .row, maxWidth: board, includesNote: true)
        board = min(board, max(140, contentHeight - spacing - padH), 900)
        let padHeight = NumberPadView.requiredHeight(for: .row, maxWidth: board, includesNote: true)
        return PuzzleLayoutMetrics(
            boardSide: board,
            placement: .belowBoard,
            numberPadWidth: board,
            numberPadHeight: padHeight,
            clusterWidth: board,
            clusterHeight: board + spacing + padHeight
        )
    }

    private static func metricsBeside(
        contentWidth: CGFloat,
        contentHeight: CGFloat,
        spacing: CGFloat,
        padWidth: CGFloat
    ) -> PuzzleLayoutMetrics {
        let maxBoardFromWidth = contentWidth - spacing - padWidth
        var board = min(maxBoardFromWidth, contentHeight, 900)
        board = max(140, board)
        board = min(maxBoardFromWidth, max(140, contentHeight), 900)
        let finalPadW = NumberPadView.requiredWidth(for: .grid3x3, maxHeight: board, boardSide: board)
        let finalPadH = NumberPadView.requiredHeight(for: .grid3x3, maxWidth: finalPadW, boardSide: board)
        return PuzzleLayoutMetrics(
            boardSide: board,
            placement: .besideBoard,
            numberPadWidth: finalPadW,
            numberPadHeight: finalPadH,
            clusterWidth: board + spacing + finalPadW,
            clusterHeight: max(board, finalPadH)
        )
    }
}
