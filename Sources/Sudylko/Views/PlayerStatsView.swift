import Charts
import SwiftUI

/// Lifetime stats on the home screen (independent of which saves still exist).
struct PlayerStatsView: View {
    @State private var stats = PlayerStatsStore.load()
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue

    private static let panelCornerRadius: CGFloat = 14
    private static let chartHeight: CGFloat = 132

    private var windowMaterial: WindowBackgroundMaterial {
        WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        .frame(maxWidth: 420)
        .onAppear { stats = PlayerStatsStore.load() }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsDidChange)) { _ in
            stats = PlayerStatsStore.load()
        }
    }

    // MARK: - Header

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Statistics")
                .font(.title2.weight(.semibold))
            if stats.totalStarted > 0 {
                Text("\(stats.totalStarted) games across all difficulties")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish a puzzle to see charts and trends here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty state

    private var emptyStatsPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent.interactiveForeground(for: colorScheme).opacity(0.85))
            Text("No games yet")
                .font(.subheadline.weight(.semibold))
            Text("Your wins, streaks, and times will show up after you play.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial,
            cornerRadius: Self.panelCornerRadius
        )
        .accessibilityLabel("Statistics. No games recorded yet.")
    }

    // MARK: - Summary row

    private var summaryMetricRow: some View {
        HStack(spacing: 10) {
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
            if hasBestWinTime {
                SummaryMetricCard(
                    title: "Best time",
                    value: formatOptionalDuration(stats.bestWinSeconds),
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
            spacing: 8
        ) {
            DetailChip(label: "Started", value: "\(stats.totalStarted)")
            if stats.totalLost > 0 {
                DetailChip(label: "Lost", value: "\(stats.totalLost)")
            }
            if stats.totalWinSeconds > 0 {
                DetailChip(label: "Total solve time", value: formatDuration(stats.totalWinSeconds))
            }
            if let average = stats.averageWinSeconds, average > 0 {
                DetailChip(label: "Average win", value: formatDuration(average))
            }
            if stats.lifetimeMistakes > 0 {
                DetailChip(label: "Mistakes", value: "\(stats.lifetimeMistakes)")
            }
        }
        .padding(14)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial,
            cornerRadius: Self.panelCornerRadius
        )
        .accessibilityLabel(lifetimeOverviewAccessibilityLabel)
    }

    // MARK: - Charts

    private var outcomesChartPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsPanelTitle(title: "Games by outcome", subtitle: "Won, lost, and still in progress")

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
        .padding(14)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial,
            cornerRadius: Self.panelCornerRadius
        )
    }

    private var winRateChartPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsPanelTitle(title: "Win rate by difficulty", subtitle: "Share of started games won")

            Chart(winRateBarPoints) { point in
                BarMark(
                    x: .value("Rate", point.percent),
                    y: .value("Difficulty", point.difficulty)
                )
                .foregroundStyle(difficultyColor(for: point.difficulty))
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(Int(point.percent.rounded()))%")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            .chartXScale(domain: 0 ... 100)
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
            .accessibilityLabel(winRateChartAccessibilityLabel)
        }
        .padding(14)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial,
            cornerRadius: Self.panelCornerRadius
        )
    }

    // MARK: - Per-difficulty detail

    private var difficultyDetailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatsPanelTitle(title: "By difficulty", subtitle: "Times and mistakes per level")

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
                    .font(.subheadline.weight(.semibold))
                Text("\(stats.customSeedWon) won of \(stats.customSeedStarted) started")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: windowMaterial,
            cornerRadius: Self.panelCornerRadius
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
            let inProgress = max(0, bucket.started - bucket.won - bucket.lost)
            return [
                OutcomeBarPoint(
                    difficulty: difficulty.displayName,
                    kind: .won,
                    count: bucket.won,
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
            let pct = Double(bucket.won) / Double(bucket.started) * 100
            return WinRateBarPoint(
                difficulty: difficulty.displayName,
                percent: pct,
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
            let pending = max(0, b.started - b.won - b.lost)
            return "\(d.displayName): \(b.won) won, \(b.lost) lost, \(pending) in progress"
        }.filter { !$0.isEmpty }
        return "Games by outcome. " + parts.joined(separator: ". ")
    }

    private var winRateChartAccessibilityLabel: String {
        let parts = GameDifficulty.allCases.compactMap { d -> String? in
            let b = stats[d]
            guard b.started > 0 else { return nil }
            return "\(d.displayName) \(formatPercent(won: b.won, of: b.started))"
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

    private func formatPercent(won: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        let pct = Int((Double(won) / Double(total) * 100).rounded())
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

private struct StatsPanelTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SummaryMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: theme.systemImage)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.tint)
                Text(difficulty.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(winRateText)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            winProgressBar
            detailGrid
        }
        .padding(14)
        .statsGlassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: material,
            cornerRadius: 14
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(difficultyAccessibilityLabel)
    }

    private var winRateText: String {
        let pct = Int((Double(bucket.won) / Double(bucket.started) * 100).rounded())
        return "\(pct)% won"
    }

    private var winProgressBar: some View {
        let fraction = bucket.started > 0 ? Double(bucket.won) / Double(bucket.started) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
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
            spacing: 8
        ) {
            DetailChip(label: "Started", value: "\(bucket.started)")
            DetailChip(label: "Won", value: "\(bucket.won)")
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
        \(bucket.started) started, \(bucket.won) won, \(bucket.lost) lost. \
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Panel chrome

private extension View {
    func statsGlassPanel(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        material: WindowBackgroundMaterial,
        cornerRadius: CGFloat
    ) -> some View {
        glassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: material,
            cornerRadius: cornerRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
        )
    }
}
