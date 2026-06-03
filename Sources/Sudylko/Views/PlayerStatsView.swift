import Charts
import SwiftUI

/// Lifetime stats (sidebar; independent of which saves still exist).
struct PlayerStatsView: View {
    var showsResetMenu = false
    var onRequestReset: ((ProgressResetKind) -> Void)?

    @State private var stats = PlayerStatsStore.load()
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.isWindowFullscreen) private var isWindowFullscreen

    private static let chartHeight: CGFloat = 132
    /// Trailing gutter inside the plot so bar percent labels are not clipped at 100%.
    private static let winRateLabelTrailingPadding: CGFloat = 34

    private var windowMaterial: WindowBackgroundMaterial {
        let stored = WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
        return stored.effective(whenFullscreen: isWindowFullscreen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.sectionSpacing) {
            statsHeader

            if stats.totalStarted == 0 {
                emptyStatsPanel
            } else {
                summaryMetricRow
                lifetimeOverviewPanel
                if !outcomeBarPoints.isEmpty {
                    outcomesChartPanel
                }
                if !winRateBarPoints.isEmpty {
                    winRateChartPanel
                }
                if !difficultiesWithGames.isEmpty {
                    difficultyDetailSection
                }
                if stats.customSeedStarted > 0 {
                    customSeedPanel
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { stats = PlayerStatsStore.load() }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsDidChange)) { _ in
            stats = PlayerStatsStore.load()
        }
    }

    // MARK: - Header

    private var statsHeader: some View {
        InspectorPageHeader(
            title: "Statistics",
            subtitle: stats.totalStarted == 0
                ? "Finish a puzzle to see charts and trends here."
                : nil,
            showsResetMenu: showsResetMenu,
            resetPanel: .statistics,
            onRequestReset: onRequestReset
        )
    }

    private func winRatePercent(won: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        let cappedWon = min(won, total)
        return min(100, Int((Double(cappedWon) / Double(total) * 100).rounded()))
    }

    // MARK: - Empty state

    private var emptyStatsPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .sudylkoSymbolFont(.statsEmptyIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent.interactiveForeground(for: colorScheme).opacity(0.85))
            Text("No games yet")
                .font(.subheadline)
            Text("Your wins, streaks, and times will show up after you play.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial
        )
        .accessibilityLabel("Statistics. No games recorded yet.")
    }

    // MARK: - Summary row

    private var summaryMetricRow: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 0) {
            GridRow {
                SummaryMetricCard(
                    title: "Won",
                    value: "\(stats.totalWon)",
                    symbol: "trophy.fill",
                    tint: accent.interactiveForeground(for: colorScheme)
                )
                SummaryMetricCard(
                    title: "Win rate",
                    value: formatPercent(won: stats.totalWon, of: stats.totalStarted),
                    symbol: "percent",
                    tint: accent.displayColor(for: colorScheme)
                )
                SummaryMetricCard(
                    title: "Best time",
                    value: hasBestWinTime
                        ? formatOptionalDuration(stats.bestWinSeconds)
                        : "—",
                    symbol: "stopwatch.fill",
                    tint: .secondary
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var lifetimeOverviewPanel: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            alignment: .leading,
            spacing: InspectorLayout.detailGridSpacing
        ) {
            DetailChip(label: "Started", value: "\(stats.totalStarted)")
            DetailChip(label: "Lost", value: "\(stats.totalLost)")
            DetailChip(
                label: "Total solve time",
                value: stats.totalWinSeconds > 0 ? formatDuration(stats.totalWinSeconds) : "—"
            )
            DetailChip(
                label: "Average win",
                value: stats.averageWinSeconds.map { $0 > 0 ? formatDuration($0) : "—" } ?? "—"
            )
            DetailChip(label: "Mistakes", value: "\(stats.lifetimeMistakes)")
        }
        .padding(InspectorLayout.panelContentPadding)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial
        )
        .accessibilityLabel(lifetimeOverviewAccessibilityLabel)
    }

    // MARK: - Charts

    private var outcomesChartPanel: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.panelInternalSpacing) {
            InspectorPanelHeading(title: "Games by outcome", subtitle: "Won, lost, and still in progress")

            Chart(outcomeBarPoints) { point in
                BarMark(
                    x: .value("Difficulty", point.difficulty),
                    y: .value("Games", point.count)
                )
                .foregroundStyle(by: .value("Outcome", point.kind.rawValue))
            }
            .chartForegroundStyleScale(
                domain: GameOutcomeKind.allCases.map(\.rawValue),
                range: [
                    accent.displayColor(for: colorScheme),
                    Color.orange.opacity(colorScheme == .dark ? 0.85 : 0.75),
                    Color.secondary.opacity(colorScheme == .dark ? 0.45 : 0.35),
                ]
            )
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text("\(n)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: Self.chartHeight)
            .accessibilityLabel(outcomesChartAccessibilityLabel)
        }
        .padding(InspectorLayout.panelContentPadding)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial
        )
    }

    private var winRateChartPanel: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.panelInternalSpacing) {
            InspectorPanelHeading(title: "Win rate by difficulty", subtitle: "Share of started games won")

            Chart(winRateBarPoints) { point in
                BarMark(
                    x: .value("Rate", min(100, point.percent)),
                    y: .value("Difficulty", point.difficulty)
                )
                .foregroundStyle(difficultyColor(for: point.difficulty))
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                    winRateBarPercentLabel(for: point.percent)
                }
            }
            .chartXScale(domain: 0 ... 100)
            .chartPlotStyle { plot in
                plot.padding(.trailing, Self.winRateLabelTrailingPadding)
            }
            .chartXAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text("\(n)%")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: Self.chartHeight)
            .padding(.trailing, 4)
            .clipped()
            .accessibilityLabel(winRateChartAccessibilityLabel)
        }
        .padding(InspectorLayout.panelContentPadding)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial
        )
    }

    // MARK: - Per-difficulty detail

    private var difficultyDetailSection: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.sectionTitleSpacing) {
            InspectorPanelHeading(title: "By difficulty", subtitle: "Times and mistakes per level")

            ForEach(difficultiesWithGames) { difficulty in
                DifficultyStatsCard(
                    difficulty: difficulty,
                    bucket: stats[difficulty],
                    accent: accent,
                    colorScheme: colorScheme,
                    material: windowMaterial
                )
            }
        }
    }

    private var customSeedPanel: some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PuzzleTheme.fromSeed.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom seed")
                    .font(.headline)
                Text("\(stats.customSeedWon) won of \(stats.customSeedStarted) started")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(InspectorLayout.panelContentPadding)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial
        )
        .accessibilityLabel("Custom seed games. \(stats.customSeedWon) won of \(stats.customSeedStarted) started.")
    }

    // MARK: - Visibility

    private var difficultiesWithGames: [GameDifficulty] {
        GameDifficulty.allCases.filter { stats[$0].started > 0 }
    }

    private var hasBestWinTime: Bool {
        guard let seconds = stats.bestWinSeconds else { return false }
        return seconds > 0
    }

    private var lifetimeOverviewAccessibilityLabel: String {
        var parts = ["Overall. \(stats.totalStarted) started"]
        if stats.totalLost > 0 {
            parts.append("\(stats.totalLost) lost")
        }
        if stats.totalWinSeconds > 0 {
            parts.append("total solve time \(formatDuration(stats.totalWinSeconds))")
        }
        if let average = stats.averageWinSeconds, average > 0 {
            parts.append("average win \(formatDuration(average))")
        }
        if stats.lifetimeMistakes > 0 {
            parts.append("\(stats.lifetimeMistakes) mistakes")
        }
        return parts.joined(separator: ", ") + "."
    }

    // MARK: - Chart data

    private var outcomeBarPoints: [OutcomeBarPoint] {
        GameDifficulty.allCases.flatMap { difficulty in
            let bucket = stats[difficulty]
            guard bucket.started > 0 else { return [OutcomeBarPoint]() }
            let inProgress = max(0, bucket.started - bucket.displayWon - bucket.lost)
            return [
                OutcomeBarPoint(
                    difficulty: difficulty.displayName,
                    kind: .won,
                    count: bucket.displayWon,
                    sortOrder: difficulty.chartSortOrder
                ),
                OutcomeBarPoint(
                    difficulty: difficulty.displayName,
                    kind: .lost,
                    count: bucket.lost,
                    sortOrder: difficulty.chartSortOrder
                ),
                OutcomeBarPoint(
                    difficulty: difficulty.displayName,
                    kind: .inProgress,
                    count: inProgress,
                    sortOrder: difficulty.chartSortOrder
                ),
            ].filter { $0.count > 0 }
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var winRateBarPoints: [WinRateBarPoint] {
        GameDifficulty.allCases.compactMap { difficulty in
            let bucket = stats[difficulty]
            guard bucket.started > 0 else { return nil }
            return WinRateBarPoint(
                difficulty: difficulty.displayName,
                percent: min(100, bucket.winRatePercent),
                sortOrder: difficulty.chartSortOrder
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func difficultyColor(for displayName: String) -> Color {
        switch displayName {
        case GameDifficulty.easy.displayName: PuzzleTheme.easy.tint
        case GameDifficulty.medium.displayName: PuzzleTheme.medium.tint
        case GameDifficulty.hard.displayName: PuzzleTheme.hard.tint
        default: accent.displayColor(for: colorScheme)
        }
    }

    private var outcomesChartAccessibilityLabel: String {
        let parts = GameDifficulty.allCases.map { d -> String in
            let b = stats[d]
            guard b.started > 0 else { return "" }
            let pending = max(0, b.started - b.displayWon - b.lost)
            return "\(d.displayName): \(b.displayWon) won, \(b.lost) lost, \(pending) in progress"
        }.filter { !$0.isEmpty }
        return "Games by outcome. " + parts.joined(separator: ". ")
    }

    private var winRateChartAccessibilityLabel: String {
        let parts = GameDifficulty.allCases.compactMap { d -> String? in
            let b = stats[d]
            guard b.started > 0 else { return nil }
            return "\(d.displayName) \(formatPercent(won: b.displayWon, of: b.started))"
        }
        return "Win rate by difficulty. " + parts.joined(separator: ". ")
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        return PuzzleTimer.format(seconds)
    }

    private func formatOptionalDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        return PuzzleTimer.format(seconds)
    }

    private func winRateBarPercentLabel(for percent: Double) -> some View {
        Text("\(Int(min(100, percent).rounded()))%")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private func formatPercent(won: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        let cappedWon = min(won, total)
        let pct = min(100, Int((Double(cappedWon) / Double(total) * 100).rounded()))
        return "\(pct)%"
    }
}

// MARK: - Chart models

private enum GameOutcomeKind: String, CaseIterable {
    case won = "Won"
    case lost = "Lost"
    case inProgress = "In progress"
}

private struct OutcomeBarPoint: Identifiable {
    let difficulty: String
    let kind: GameOutcomeKind
    let count: Int
    let sortOrder: Int
    var id: String { "\(difficulty)-\(kind.rawValue)" }
}

private struct WinRateBarPoint: Identifiable {
    let difficulty: String
    let percent: Double
    let sortOrder: Int
    var id: String { difficulty }
}

private extension GameDifficulty {
    var chartSortOrder: Int {
        switch self {
        case .easy: 0
        case .medium: 1
        case .hard: 2
        }
    }
}

// MARK: - Subviews

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.summaryCardInternalSpacing) {
            Image(systemName: symbol)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(
                    maxWidth: .infinity,
                    minHeight: InspectorLayout.summaryCardIconHeight,
                    maxHeight: InspectorLayout.summaryCardIconHeight,
                    alignment: .leading
                )
            Text(value)
                .font(.title2)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(
                    maxWidth: .infinity,
                    minHeight: InspectorLayout.summaryCardValueMinHeight,
                    alignment: .leading
                )
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
                .frame(
                    maxWidth: .infinity,
                    minHeight: InspectorLayout.summaryCardTitleMinHeight,
                    alignment: .topLeading
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(InspectorLayout.summaryCardPadding)
        .inspectorSummaryCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

private struct DifficultyStatsCard: View {
    let difficulty: GameDifficulty
    let bucket: DifficultyPlayerStats
    let accent: AppAccentColor
    let colorScheme: ColorScheme
    let material: WindowBackgroundMaterial

    private var theme: PuzzleTheme { .forDifficulty(difficulty) }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.panelInternalSpacing) {
            HStack(spacing: 8) {
                Image(systemName: theme.systemImage)
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.tint)
                Text(difficulty.displayName)
                    .font(.headline)
                Spacer()
                Text(winRateText)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            winProgressBar
            detailGrid
        }
        .padding(InspectorLayout.panelContentPadding)
        .inspectorGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: material
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(difficultyAccessibilityLabel)
    }

    private var winRateText: String {
        let pct = Int(bucket.winRatePercent.rounded())
        return "\(pct)% won"
    }

    private var winProgressBar: some View {
        let fraction = min(1, bucket.winRatePercent / 100)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        Color.primary.opacity(InspectorSurface.progressTrackOpacity(for: colorScheme))
                    )
                Capsule()
                    .fill(theme.tint.gradient)
                    .frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var detailGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            alignment: .leading,
            spacing: InspectorLayout.detailGridSpacing
        ) {
            DetailChip(label: "Started", value: "\(bucket.started)")
            DetailChip(label: "Won", value: "\(bucket.displayWon)")
            if bucket.lost > 0 {
                DetailChip(label: "Lost", value: "\(bucket.lost)")
            }
            if let best = bucket.bestWinSeconds, best > 0 {
                DetailChip(label: "Best", value: formatOptionalDuration(best))
            }
            if let average = bucket.averageWinSeconds, average > 0 {
                DetailChip(label: "Average", value: formatDuration(average))
            }
            if bucket.totalWinSeconds > 0 {
                DetailChip(label: "Total time", value: formatDuration(bucket.totalWinSeconds))
            }
            if bucket.mistakes > 0 {
                DetailChip(label: "Mistakes", value: "\(bucket.mistakes)")
            }
        }
    }

    private var difficultyAccessibilityLabel: String {
        """
        \(difficulty.displayName). \(winRateText). \
        \(bucket.started) started, \(bucket.displayWon) won, \(bucket.lost) lost. \
        Best time \(formatOptionalDuration(bucket.bestWinSeconds)).
        """
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        return PuzzleTimer.format(seconds)
    }

    private func formatOptionalDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        return PuzzleTimer.format(seconds)
    }
}

private struct DetailChip: View {
    let label: String
    let value: String

    private static let labelHeight: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.detailChipSpacing) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, minHeight: Self.labelHeight, alignment: .topLeading)
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

