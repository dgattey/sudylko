import SwiftUI

/// All achievements and lock state, shown on the home screen.
struct AchievementsListView: View {
    @State private var unlockedIDs = AchievementStore.unlockedIDs()
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    private var unlockedCount: Int {
        AchievementID.displayOrder.filter { unlockedIDs.contains($0.rawValue) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(unlockedCount) of \(AchievementID.displayOrder.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(AchievementID.displayOrder.enumerated()), id: \.element.id) { index, achievement in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 44)
                    }
                    AchievementRowView(
                        achievement: achievement,
                        isUnlocked: unlockedIDs.contains(achievement.rawValue)
                    )
                }
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(colorScheme == .dark ? 0.35 : 0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: 420)
        .onAppear {
            unlockedIDs = AchievementStore.unlockedIDs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsDidChange)) { _ in
            unlockedIDs = AchievementStore.unlockedIDs()
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
            .font(.body.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(achievement.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
