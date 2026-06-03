import SwiftUI

struct AppearancePickerView: View {
    @Binding var appearanceRaw: String
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
            FormSectionLabel(title: "Appearance")

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
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .inspectorSegmentSelection(
                isSelected: isSelected,
                accent: accent,
                colorScheme: colorScheme,
                cornerRadius: ThemeMetrics.controlCornerRadius
            )
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(InspectorSurface.borderOpacity(for: colorScheme)),
                            lineWidth: 1
                        )
                }
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
