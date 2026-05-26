import SwiftUI

/// Visual identity shared by quick-start tiles and the in-game sidebar status.
enum PuzzleTheme: Equatable {
    case easy
    case medium
    case hard
    case fromSeed

    static func forDifficulty(_ difficulty: GameDifficulty) -> PuzzleTheme {
        switch difficulty {
        case .easy: .easy
        case .medium: .medium
        case .hard: .hard
        }
    }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .fromSeed: "From seed"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "More starting clues"
        case .medium: "Balanced challenge"
        case .hard: "Fewer clues"
        case .fromSeed: "Enter a puzzle number like 1384"
        }
    }

    var systemImage: String {
        switch self {
        case .easy: "leaf.fill"
        case .medium: "gauge.with.dots.needle.50percent"
        case .hard: "flame.fill"
        case .fromSeed: "number"
        }
    }

    var tint: Color {
        switch self {
        case .easy: .green
        case .medium: .blue
        case .hard: .orange
        case .fromSeed: .purple
        }
    }
}

enum SidebarMetrics {
    static let width: CGFloat = 260
    static let horizontalPadding: CGFloat = 16
    /// Inset applied only to the selection chrome behind a save row (not row content).
    static let selectionBackgroundHorizontalInset: CGFloat = 8
    /// Vertical padding inside each save row.
    static let saveRowContentPadding: CGFloat = 10
    /// Extra space between save rows (split across adjacent row insets).
    static let saveRowInterItemGap: CGFloat = 8
    static var saveRowInsets: EdgeInsets {
        let vertical = saveRowContentPadding + saveRowInterItemGap / 2
        return EdgeInsets(top: vertical, leading: 0, bottom: vertical, trailing: 0)
    }
}
