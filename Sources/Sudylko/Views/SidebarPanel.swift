import SwiftUI

/// Games / Statistics / Achievements switcher (no `Picker` label — avoids crushed sidebar layout on macOS).
struct SidebarPanelPicker: View {
    @Binding var selection: SidebarPanel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SidebarPanel.allCases) { panel in
                segment(for: panel)
            }
        }
        .padding(3)
        .inspectorControlTrack()
        .frame(maxWidth: .infinity)
    }

    private func segment(for panel: SidebarPanel) -> some View {
        let isSelected = selection == panel
        return Button {
            selection = panel
        } label: {
            Image(systemName: panel.symbolName)
                .font(.body)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .inspectorSegmentSelection(
            isSelected: isSelected,
            accent: accent,
            colorScheme: colorScheme
        )
        .accessibilityLabel(panel.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .macOSTooltip(panel.title)
    }
}

/// Primary sidebar destinations (games list, statistics, achievements).
enum SidebarPanel: String, CaseIterable, Identifiable, Hashable {
    case games
    case statistics
    case achievements

    var id: String { rawValue }

    var title: String {
        switch self {
        case .games: "Games"
        case .statistics: "Statistics"
        case .achievements: "Achievements"
        }
    }

    var symbolName: String {
        switch self {
        case .games: "rectangle.stack"
        case .statistics: "chart.bar"
        case .achievements: "trophy"
        }
    }
}

enum ProgressResetKind: String, Identifiable {
    case statistics
    case achievements
    case archivedGames
    case all

    var id: String { rawValue }

    var modalTitle: String {
        switch self {
        case .statistics: "Reset statistics?"
        case .achievements: "Reset achievements?"
        case .archivedGames: "Delete archived games?"
        case .all: "Reset all progress?"
        }
    }

    var modalMessage: String {
        switch self {
        case .statistics:
            "Clears lifetime win/loss counts, times, and charts. Saved games are not deleted."
        case .achievements:
            "Locks every achievement again. Statistics are kept."
        case .archivedGames:
            "Permanently deletes every archived game. Statistics and achievements are kept."
        case .all:
            "Clears all statistics, locks every achievement, and deletes all saved games."
        }
    }

    var confirmTitle: String {
        switch self {
        case .statistics: "Reset statistics"
        case .achievements: "Reset achievements"
        case .archivedGames: "Delete archived"
        case .all: "Reset all"
        }
    }

    /// Resets the progress-defaults portion of a kind. Save-file side effects are handled by the
    /// caller (it owns the active-game/UI state).
    static func perform(_ kind: ProgressResetKind) {
        switch kind {
        case .statistics:
            AchievementStore.resetStats()
        case .achievements:
            AchievementStore.resetUnlocks()
        case .all:
            AchievementStore.resetAllProgress()
        case .archivedGames:
            break
        }
    }
}

struct ProgressResetModal: View {
    let kind: ProgressResetKind
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        SudylkoModal(title: kind.modalTitle, subtitle: kind.modalMessage) {
            EmptyView()
        } footer: {
            SudylkoModalFooter(
                onCancel: onCancel,
                primaryTitle: kind.confirmTitle,
                primaryRole: .destructive,
                onPrimary: onConfirm
            )
        }
    }
}

struct ProgressResetMenu: View {
    var panel: SidebarPanel
    var onSelect: (ProgressResetKind) -> Void

    var body: some View {
        Menu {
            if panel == .statistics {
                Button("Reset statistics…", role: .destructive) {
                    onSelect(.statistics)
                }
            }
            if panel == .achievements {
                Button("Reset achievements…", role: .destructive) {
                    onSelect(.achievements)
                }
            }
            Button("Reset all progress…", role: .destructive) {
                onSelect(.all)
            }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .macOSTooltip("Reset progress")
    }
}
