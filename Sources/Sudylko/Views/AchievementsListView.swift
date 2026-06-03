import SwiftUI

/// All achievements and lock state (sidebar or inspector).
struct AchievementsListView: View {
    var showsResetMenu = false
    var onRequestReset: ((ProgressResetKind) -> Void)?

    @State private var unlockedIDs = AchievementStore.unlockedIDs()

    private var unlockedAchievements: [AchievementID] {
        AchievementID.displayOrder.filter { unlockedIDs.contains($0.rawValue) }
    }

    private var remainingAchievements: [AchievementID] {
        AchievementID.displayOrder.filter { !unlockedIDs.contains($0.rawValue) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.sectionSpacing) {
            InspectorPageHeader(
                title: "Achievements",
                showsResetMenu: showsResetMenu,
                resetPanel: .achievements,
                onRequestReset: onRequestReset
            )

            if !unlockedAchievements.isEmpty {
                achievementSection(
                    title: "Completed (\(unlockedAchievements.count))",
                    achievements: unlockedAchievements
                )
            }

            if !remainingAchievements.isEmpty {
                achievementSection(
                    title: "Remaining (\(remainingAchievements.count))",
                    achievements: remainingAchievements
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            unlockedIDs = AchievementStore.unlockedIDs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsDidChange)) { _ in
            unlockedIDs = AchievementStore.unlockedIDs()
        }
    }

    private func achievementSection(title: String, achievements: [AchievementID]) -> some View {
        VStack(alignment: .leading, spacing: InspectorLayout.sectionTitleSpacing) {
            InspectorSectionLabel(title: title)
            achievementList(achievements)
        }
    }

    private func achievementList(_ achievements: [AchievementID]) -> some View {
        InspectorGroupedList {
            VStack(spacing: 8) {
                ForEach(achievements) { achievement in
                    AchievementRowView(
                        achievement: achievement,
                        isUnlocked: unlockedIDs.contains(achievement.rawValue)
                    )
                }
            }
        }
    }
}

private struct AchievementRowView: View {
    let achievement: AchievementID
    let isUnlocked: Bool

    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if isUnlocked {
                    Image(systemName: achievement.systemImage)
                        .foregroundStyle(accent.interactiveForeground(for: colorScheme))
                } else {
                    Image(systemName: achievement.systemImage)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.headline)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: InspectorLayout.detailChipSpacing) {
                Text(achievement.title)
                    .font(.subheadline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(achievement.subtitle)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Group {
                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent.interactiveForeground(for: colorScheme))
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.quaternary)
                }
            }
            .font(.body)
        }
        .inspectorListRowPadding()
    }
}
