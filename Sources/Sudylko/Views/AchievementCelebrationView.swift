import SwiftUI

struct AchievementCelebrationView: View {
    let achievement: AchievementID
    var onDismiss: () -> Void

    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: achievement.systemImage)
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(accent.displayColor(for: colorScheme), Color.primary.opacity(0.2))
                .symbolEffect(.bounce, value: isVisible)

            VStack(spacing: 4) {
                Text("Achievement Unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(achievement.title)
                    .font(.title2.weight(.bold))

                Text(achievement.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: 320)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.selectionBorder(for: colorScheme).opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .scaleEffect(isVisible ? 1 : 0.82)
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
