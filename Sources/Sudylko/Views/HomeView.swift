import SwiftUI

/// Home screen: new-puzzle quick-start tiles.
struct HomeView: View {
    var onEasy: () -> Void
    var onMedium: () -> Void
    var onHard: () -> Void
    var onFromSeed: () -> Void

    private let tileColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private static let gridMaxWidth: CGFloat = 420
    #if os(macOS)
    private static let leftColumnMaxWidth: CGFloat = WindowLayoutMetrics.homeDetailMinWidth
    #else
    private static let leftColumnMaxWidth: CGFloat = 460
    #endif

    var body: some View {
        ScrollView {
            newPuzzleColumn
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
                .frame(maxWidth: Self.leftColumnMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var newPuzzleColumn: some View {
        VStack(spacing: 24) {
            homeHeader
            newPuzzleSection
        }
    }

    private var homeHeader: some View {
        VStack(spacing: 6) {
            Text("Start a new game")
                .font(.largeTitle)
            Text("Pick a difficulty to begin a new puzzle.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var newPuzzleSection: some View {
        VStack(spacing: InspectorLayout.sectionContentSpacing) {
            InspectorSectionLabel(title: "New puzzle")

            LazyVGrid(columns: tileColumns, spacing: 16) {
                QuickStartTile(theme: .easy, action: onEasy)
                QuickStartTile(theme: .medium, action: onMedium)
                QuickStartTile(theme: .hard, action: onHard)
                QuickStartTile(theme: .fromSeed, action: onFromSeed)
            }
            .frame(maxWidth: Self.gridMaxWidth)
        }
    }
}
