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

    #if os(macOS)
    /// Scroll content inset inside NavigationSplitView’s rounded sidebar column.
    static let columnScrollContentMargin: CGFloat = 10
    /// Fixed chrome inset for header/footer above the scrolling list.
    static let columnEdgePadding: CGFloat = 8
    #endif
}

#if os(macOS)
/// Minimum window size given which home chrome columns are visible.
enum WindowLayoutMetrics {
    static let minHeight: CGFloat = 640
    /// Matches `HomeView` center column content width.
    static let homeDetailMinWidth: CGFloat = 460
    static let homeInspectorMinWidth: CGFloat = 260
    static func minimumSize(
        showsSidebar: Bool,
        showsHomeInspector: Bool
    ) -> CGSize {
        var width = homeDetailMinWidth
        if showsSidebar {
            width += SidebarMetrics.width
        }
        if showsHomeInspector {
            width += homeInspectorMinWidth
        }
        return CGSize(
            width: max(780, width),
            height: minHeight
        )
    }
}
#endif
