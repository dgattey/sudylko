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
        case .fromSeed: "Enter or paste a puzzle number"
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
    static let width: CGFloat = 300
    static let horizontalPadding: CGFloat = 16
    /// Inset applied only to the selection chrome behind a save row (not row content).
    static let selectionBackgroundHorizontalInset: CGFloat = 8
    /// Vertical padding inside each save row.
    static let saveRowContentPadding: CGFloat = 10
    /// Extra space between save rows (split across adjacent row insets).
    static let saveRowInterItemGap: CGFloat = 8
    /// Space above a list section title (macOS sidebar headers sit tight by default).
    static let sectionHeaderTopPadding: CGFloat = 10
    /// Space between section title and first row in that section.
    static let sectionHeaderBottomPadding: CGFloat = 8
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

/// Spacing and metrics for inspector panes, home section labels, and grouped lists.
enum InspectorLayout {
    static let sectionSpacing: CGFloat = 18
    static let sectionTitleSpacing: CGFloat = 12
    /// Space between a section label and its primary content (e.g. tile grid).
    static let sectionContentSpacing: CGFloat = 16
    static let scrollVerticalPadding: CGFloat = 8
    static let pageSubtitleSpacing: CGFloat = 6

    static let panelCornerRadius: CGFloat = 14
    static let panelContentPadding: CGFloat = 18
    static let panelInternalSpacing: CGFloat = 14
    static let panelHeadingSpacing: CGFloat = 5

    static let listCardCornerRadius: CGFloat = 12
    static let groupedListVerticalPadding: CGFloat = 4
    static let groupedListDividerLeadingInset: CGFloat = 44
    static let listRowHorizontalPadding: CGFloat = 14
    static let listRowVerticalPadding: CGFloat = 10

    static let detailChipSpacing: CGFloat = 5
    static let detailGridSpacing: CGFloat = 10

    static let summaryCardCornerRadius: CGFloat = 10
    static let summaryCardPadding: CGFloat = 14
    static let summaryCardInternalSpacing: CGFloat = 10
    /// Fixed vertical slots so three-up summary cards stay equal height when labels wrap.
    static let summaryCardIconHeight: CGFloat = 22
    static let summaryCardValueMinHeight: CGFloat = 30
    static let summaryCardTitleMinHeight: CGFloat = 32

    /// Corner radius for selected segments in sidebar/inspector segmented controls.
    static let controlSegmentCornerRadius: CGFloat = 6
    static let controlTrackCornerRadius: CGFloat = 8
}

/// Spacing for settings popover and other compact forms.
enum FormLayout {
    static let groupSpacing: CGFloat = 20
    static let sectionSpacing: CGFloat = 8
    static let controlDetailSpacing: CGFloat = 4
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
