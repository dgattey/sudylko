import SwiftUI

enum GameOverlayPhase: Equatable {
    case puzzleEnd(PuzzleEndBannerView.Kind)
}

/// Single full-screen overlay: win/loss or achievement — never stacked. Loading uses `LoadingPuzzleSkeleton`.
struct GameOverlayHost: View {
    @Environment(\.appAccent) private var accent

    let phase: GameOverlayPhase?
    let achievements: [AchievementID]
    let formattedElapsed: String
    let buttonTint: Color
    let colorScheme: ColorScheme
    var onDismissAchievement: () -> Void
    var onDismissPuzzleEnd: () -> Void
    var onEndGameAction: () -> Void

    private var activeKind: ActiveOverlayKind? {
        if !achievements.isEmpty {
            return .achievement(achievements)
        }
        if case .puzzleEnd(let endKind) = phase {
            return .puzzleEnd(endKind)
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let activeKind {
                overlayScrim(for: activeKind)
                    .transition(.opacity)

                overlayCard(activeKind)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.88).combined(with: .opacity),
                            removal: .scale(scale: 0.94).combined(with: .opacity)
                        )
                    )
                    .id(activeKind.transitionID)
            }
        }
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: activeKind?.transitionID)
        .accessibilityElement(children: .contain)
    }

    private func overlayScrim(for kind: ActiveOverlayKind) -> some View {
        Color.black.opacity(colorScheme == .dark ? 0.52 : 0.38)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                switch kind {
                case .puzzleEnd:
                    onDismissPuzzleEnd()
                case .achievement:
                    onDismissAchievement()
                }
            }
    }

    @ViewBuilder
    private func overlayCard(_ kind: ActiveOverlayKind) -> some View {
        switch kind {
        case .puzzleEnd(let endKind):
            PuzzleEndBannerView(
                kind: endKind,
                formattedElapsed: formattedElapsed,
                buttonTint: buttonTint,
                colorScheme: colorScheme,
                onDismiss: onDismissPuzzleEnd,
                onButton: onEndGameAction
            )
        case .achievement(let ids):
            GameOverlayCardChrome(
                accent: accent.displayColor(for: colorScheme),
                colorScheme: colorScheme
            ) {
                AchievementCelebrationContent(achievements: ids, onDismiss: onDismissAchievement)
            }
        }
    }
}

// MARK: - Shared chrome

private enum ActiveOverlayKind {
    case puzzleEnd(PuzzleEndBannerView.Kind)
    case achievement([AchievementID])

    var transitionID: String {
        switch self {
        case .puzzleEnd(.won):
            return "won"
        case .puzzleEnd(.lost):
            return "lost"
        case .achievement(let ids):
            return "achievement-" + ids.map(\.rawValue).joined(separator: "-")
        }
    }
}

struct GameOverlayCardChrome<Content: View>: View {
    let accent: Color?
    let colorScheme: ColorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(minWidth: 340, maxWidth: 440)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThickMaterial)
                if let accent {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(accent.opacity(colorScheme == .dark ? 0.14 : 0.1))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        (accent ?? Color.primary).opacity(colorScheme == .dark ? 0.35 : 0.2),
                        lineWidth: 1.5
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.55 : 0.22),
                radius: 36,
                y: 14
            )
    }
}

/// Achievement body used inside `GameOverlayHost`. Shows a single hero card or, when several
/// achievements unlock at once, all of them together in one modal.
private struct AchievementCelebrationContent: View {
    let achievements: [AchievementID]
    var onDismiss: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false
    @State private var selectedAchievement: AchievementID?
    @State private var dismissTask: Task<Void, Never>?

    private var accentColor: Color { accent.displayColor(for: colorScheme) }

    private var isBatch: Bool { achievements.count > 1 }

    /// A touch longer for batches so the staggered reveal lands; capped so it never lingers.
    private var visibleDuration: Double {
        isBatch ? min(7.0, 3.5 + 0.25 * Double(achievements.count)) : 3.2
    }

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                if isBatch { selectedAchievement = achievements.first }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    isVisible = true
                }
                startAutoDismiss()
            }
            .onDisappear { dismissTask?.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        if let achievement = achievements.first, !isBatch {
            singleAchievement(achievement)
                .scaleEffect(isVisible ? 1 : 0.88)
        } else {
            batchContent
        }
    }

    private func singleAchievement(_ achievement: AchievementID) -> some View {
        VStack(spacing: 18) {
            Image(systemName: achievement.systemImage)
                .sudylkoSymbolFont(.overlayHero)
                .symbolRenderingMode(.palette)
                .foregroundStyle(accentColor, Color.primary.opacity(0.2))
                .symbolEffect(.bounce, value: isVisible)

            VStack(spacing: 8) {
                eyebrow

                Text(achievement.title)
                    .font(.title2)

                Text(achievement.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Batch reveal (staggered, tappable icon grid + detail)

    private var batchContent: some View {
        VStack(spacing: 22) {
            eyebrow
            gridScrollIfNeeded

            VStack(spacing: 16) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                detailPanel
            }
            .padding(.top, 4)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: selectedAchievement)
    }

    /// Plain grid for small batches (hugs content). Large batches scroll within a cap so the
    /// modal never overflows the window.
    @ViewBuilder
    private var gridScrollIfNeeded: some View {
        if achievements.count > 12 {
            ScrollView {
                gridContent
                    .padding(.vertical, 2)
            }
            .frame(maxHeight: 320)
            .scrollBounceBehavior(.basedOnSize)
        } else {
            gridContent
        }
    }

    private var batchColumns: Int { min(4, max(1, achievements.count)) }

    /// Manual rows (instead of `LazyVGrid`) so an incomplete trailing row stays centered.
    private var achievementRows: [[AchievementID]] {
        stride(from: 0, to: achievements.count, by: batchColumns).map { start in
            Array(achievements[start..<min(start + batchColumns, achievements.count)])
        }
    }

    private var gridContent: some View {
        VStack(spacing: 18) {
            ForEach(Array(achievementRows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 16) {
                    ForEach(Array(row.enumerated()), id: \.element) { columnIndex, achievement in
                        gridCell(achievement, index: rowIndex * batchColumns + columnIndex)
                            .frame(width: 78)
                    }
                }
            }
        }
    }

    private func gridCell(_ achievement: AchievementID, index: Int) -> some View {
        let isSelected = achievement == selectedAchievement
        return VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(chipFillOpacity(isSelected: isSelected)))
                Circle()
                    .strokeBorder(accentColor.opacity(isSelected ? 0.9 : 0), lineWidth: 2.5)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(accentColor, Color.primary.opacity(0.25))
                    .symbolEffect(.bounce, value: isVisible)
            }
            .frame(width: 72, height: 72)
            .scaleEffect(isSelected ? 1.08 : 1)

            Text(achievement.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .foregroundStyle(isSelected ? Color.primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .scaleEffect(isVisible ? 1 : 0.3)
        .opacity(isVisible ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.62).delay(0.05 * Double(index)),
            value: isVisible
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            dismissTask?.cancel()
            selectedAchievement = achievement
        }
    }

    private func chipFillOpacity(isSelected: Bool) -> Double {
        if colorScheme == .dark {
            return isSelected ? 0.32 : 0.18
        }
        return isSelected ? 0.24 : 0.12
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let selected = selectedAchievement {
            VStack(spacing: 4) {
                Text(selected.title)
                    .font(.headline)
                Text(selected.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .id(selected)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
        }
    }

    private var eyebrow: some View {
        Text(isBatch ? "\(achievements.count) Achievements Unlocked" : "Achievement Unlocked")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func startAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(visibleDuration))
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    isVisible = false
                }
            }
            try? await Task.sleep(for: .milliseconds(240))
            if Task.isCancelled { return }
            await MainActor.run {
                onDismiss()
            }
        }
    }
}
