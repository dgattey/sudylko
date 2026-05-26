import SwiftUI

struct AppearancePickerView: View {
    @Binding var appearanceRaw: String
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in
                    AppearanceOptionButton(
                        mode: mode,
                        isSelected: appearanceRaw == mode.rawValue,
                        accent: accent,
                        colorScheme: colorScheme
                    ) {
                        appearanceRaw = mode.rawValue
                    }
                }
            }
        }
    }
}

private struct AppearanceOptionButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let accent: AppAccentColor
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? accent.interactiveForeground(for: colorScheme) : .secondary)
                    .frame(width: 36, height: 28)
                Text(mode.displayName)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                    .fill(isSelected ? accent.selectionFill(for: colorScheme) : Color.primary.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.selectionBorder(for: colorScheme) : Color.primary.opacity(0.1),
                        lineWidth: isSelected && accent.prefersStrongSelectionBorder ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .sudylkoFocusSuppressed()
    }

    private var iconName: String {
        switch mode {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
