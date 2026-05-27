import SwiftUI

/// Home screen: new-puzzle tiles and progress summary cards; progress uses the attached inspector (see `ContentView`).
struct HomeView: View {
    var onEasy: () -> Void
    var onMedium: () -> Void
    var onHard: () -> Void
    var onFromSeed: () -> Void
    @Binding var inspectorPresented: Bool
    @Binding var inspectorSection: HomeProgressSection?

    @Environment(\.digitFontStyle) private var digitFontStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent
    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.isWindowFullscreen) private var isWindowFullscreen

    @State private var lifetimeStats = PlayerStatsStore.load()
    @State private var unlockedAchievementIDs = AchievementStore.unlockedIDs()

    private let tileColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private let cardColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private static let gridMaxWidth: CGFloat = 420
    #if os(macOS)
    private static let leftColumnMaxWidth: CGFloat = WindowLayoutMetrics.homeDetailMinWidth
    #else
    private static let leftColumnMaxWidth: CGFloat = 460
    #endif

    private var windowMaterial: WindowBackgroundMaterial {
        let stored = WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
        return stored.effective(whenFullscreen: isWindowFullscreen)
    }

    private var unlockedAchievementCount: Int {
        AchievementID.displayOrder.filter { unlockedAchievementIDs.contains($0.rawValue) }.count
    }

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
        .onAppear { refreshProgressData() }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsDidChange)) { _ in
            refreshProgressData()
        }
    }

    private var newPuzzleColumn: some View {
        VStack(spacing: 24) {
            homeHeader
            newPuzzleSection
            progressCards
        }
    }

    private var homeHeader: some View {
        VStack(spacing: 6) {
            Text("Start a new game")
                .font(digitFontStyle.font(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Pick a difficulty to begin a new puzzle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressCards: some View {
        LazyVGrid(columns: cardColumns, spacing: 12) {
            HomeProgressSummaryCard(
                kind: .statistics,
                stats: lifetimeStats,
                unlockedAchievementCount: unlockedAchievementCount,
                totalAchievements: AchievementID.displayOrder.count,
                accent: accent,
                colorScheme: colorScheme,
                material: windowMaterial,
                isSelected: inspectorPresented && inspectorSection == .statistics,
                action: { toggleProgressInspector(.statistics) }
            )
            HomeProgressSummaryCard(
                kind: .achievements,
                stats: lifetimeStats,
                unlockedAchievementCount: unlockedAchievementCount,
                totalAchievements: AchievementID.displayOrder.count,
                accent: accent,
                colorScheme: colorScheme,
                material: windowMaterial,
                isSelected: inspectorPresented && inspectorSection == .achievements,
                action: { toggleProgressInspector(.achievements) }
            )
        }
        .frame(maxWidth: Self.gridMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private var newPuzzleSection: some View {
        VStack(spacing: 16) {
            Text("New puzzle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: tileColumns, spacing: 16) {
                QuickStartTile(theme: .easy, action: onEasy)
                QuickStartTile(theme: .medium, action: onMedium)
                QuickStartTile(theme: .hard, action: onHard)
                QuickStartTile(theme: .fromSeed, action: onFromSeed)
            }
            .frame(maxWidth: Self.gridMaxWidth)
        }
    }

    private func toggleProgressInspector(_ section: HomeProgressSection) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if inspectorPresented, inspectorSection == section {
                inspectorPresented = false
                inspectorSection = nil
            } else {
                inspectorSection = section
                inspectorPresented = true
            }
        }
    }

    private func refreshProgressData() {
        lifetimeStats = PlayerStatsStore.load()
        unlockedAchievementIDs = AchievementStore.unlockedIDs()
    }
}

// MARK: - Progress summary cards

private struct HomeProgressSummaryCard: View {
    enum Kind {
        case statistics
        case achievements

    }

    let kind: Kind
    let stats: PlayerLifetimeStats
    let unlockedAchievementCount: Int
    let totalAchievements: Int
    let accent: AppAccentColor
    let colorScheme: ColorScheme
    let material: WindowBackgroundMaterial
    let isSelected: Bool
    let action: () -> Void

    private static let cornerRadius: CGFloat = 14

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: iconName)
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(iconTint)
                    Spacer(minLength: 0)
                    Text(isSelected ? "Close" : "Open")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(trailingLabelTint)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(14)
            .glassPanel(
                accent: accent,
                colorScheme: colorScheme,
                material: material,
                cornerRadius: Self.cornerRadius
            )
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .sudylkoFocusSuppressed()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .strokeBorder(
                accent.displayColor(for: colorScheme).opacity(isSelected ? 0.55 : 0.18),
                lineWidth: isSelected ? 2 : 1
            )
    }

    private var title: String {
        switch kind {
        case .statistics: "Statistics"
        case .achievements: "Achievements"
        }
    }

    private var iconName: String {
        switch kind {
        case .statistics: "chart.bar.fill"
        case .achievements: "trophy.fill"
        }
    }

    private var trailingLabelTint: Color {
        isSelected
            ? accent.displayColor(for: colorScheme)
            : Color.secondary.opacity(0.75)
    }

    private var iconTint: Color {
        switch kind {
        case .statistics:
            accent.interactiveForeground(for: colorScheme)
        case .achievements:
            accent.displayColor(for: colorScheme)
        }
    }

    private var subtitle: String {
        switch kind {
        case .statistics:
            if stats.totalStarted == 0 {
                return "Play a puzzle to unlock charts"
            }
            let rate = winRatePercent(won: stats.totalWon, of: stats.totalStarted)
            return "\(stats.totalWon) won · \(rate)% win rate"
        case .achievements:
            return "\(unlockedAchievementCount) of \(totalAchievements) unlocked"
        }
    }

    private var accessibilityLabel: String {
        "\(title), \(subtitle)"
    }

    private var accessibilityHint: String {
        #if os(iOS)
        if isSelected {
            return "Closes \(title.lowercased())"
        }
        return "Opens \(title.lowercased())"
        #else
        if isSelected {
            return "Closes the \(title.lowercased()) inspector"
        }
        return "Opens \(title.lowercased()) in the progress inspector"
        #endif
    }

    private func winRatePercent(won: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        let cappedWon = min(won, total)
        return min(100, Int((Double(cappedWon) / Double(total) * 100).rounded()))
    }
}
