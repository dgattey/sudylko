import SwiftUI

enum GameOverlayPhase: Equatable {
    case loading(String)
    case puzzleEnd(PuzzleEndBannerView.Kind)
}

/// Single full-screen overlay: loading, win/loss, or achievement — never stacked.
struct GameOverlayHost: View {
    @Environment(\.appAccent) private var accent

    let phase: GameOverlayPhase?
    let achievement: AchievementID?
    let formattedElapsed: String
    let buttonTint: Color
    let colorScheme: ColorScheme
    var onDismissAchievement: () -> Void
    var onDismissPuzzleEnd: () -> Void
    var onEndGameAction: () -> Void

    private var activeKind: ActiveOverlayKind? {
        if case .loading = phase, let phase {
            return .phase(phase)
        }
        if let achievement {
            return .achievement(achievement)
        }
        if let phase {
            return .phase(phase)
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
                case .phase(.puzzleEnd):
                    onDismissPuzzleEnd()
                case .achievement:
                    onDismissAchievement()
                case .phase(.loading):
                    break
                }
            }
    }

    @ViewBuilder
    private func overlayCard(_ kind: ActiveOverlayKind) -> some View {
        switch kind {
        case .phase(let phase):
            switch phase {
            case .loading(let message):
                GameOverlayCardChrome(accent: nil, colorScheme: colorScheme) {
                    loadingContent(message: message)
                }
            case .puzzleEnd(let endKind):
                PuzzleEndBannerView(
                    kind: endKind,
                    formattedElapsed: formattedElapsed,
                    buttonTint: buttonTint,
                    colorScheme: colorScheme,
                    onDismiss: onDismissPuzzleEnd,
                    onButton: onEndGameAction
                )
            }
        case .achievement(let id):
            GameOverlayCardChrome(
                accent: accent.displayColor(for: colorScheme),
                colorScheme: colorScheme
            ) {
                AchievementCelebrationContent(achievement: id, onDismiss: onDismissAchievement)
            }
        }
    }

    private func loadingContent(message: String) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 280)
        .accessibilityLabel(message)
    }
}

// MARK: - Shared chrome

private enum ActiveOverlayKind {
    case phase(GameOverlayPhase)
    case achievement(AchievementID)

    var transitionID: String {
        switch self {
        case .phase(let phase):
            switch phase {
            case .loading(let message):
                return "loading-\(message)"
            case .puzzleEnd(.won):
                return "won"
            case .puzzleEnd(.lost):
                return "lost"
            }
        case .achievement(let id):
            return "achievement-\(id.rawValue)"
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

/// Achievement body used inside `GameOverlayHost` (same timing as before).
private struct AchievementCelebrationContent: View {
    let achievement: AchievementID
    var onDismiss: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: achievement.systemImage)
                .sudylkoSymbolFont(.overlayHero)
                .symbolRenderingMode(.palette)
                .foregroundStyle(accent.displayColor(for: colorScheme), Color.primary.opacity(0.2))
                .symbolEffect(.bounce, value: isVisible)

            VStack(spacing: 8) {
                Text("Achievement Unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(achievement.title)
                    .font(.title2)

                Text(achievement.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .scaleEffect(isVisible ? 1 : 0.88)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                isVisible = true
            }
            Task {
                try? await Task.sleep(for: .seconds(3.2))
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.22)) {
                        isVisible = false
                    }
                }
                try? await Task.sleep(for: .milliseconds(240))
                await MainActor.run {
                    onDismiss()
                }
            }
        }
    }
}
