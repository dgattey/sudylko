import SwiftUI

struct DigitFontPickerView: View {
    @Binding var fontStyleRaw: String
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private var selected: DigitFontStyle {
        DigitFontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(DigitFontStyle.allCases) { style in
                    Button {
                        fontStyleRaw = style.rawValue
                    } label: {
                        Text("12")
                            .font(style.font(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                                    .fill(selected == style ? accent.selectionFill(for: colorScheme) : Color.primary.opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: ThemeMetrics.controlCornerRadius, style: .continuous)
                                    .strokeBorder(
                                        selected == style ? accent.selectionBorder(for: colorScheme) : Color.primary.opacity(0.1),
                                        lineWidth: selected == style && accent.prefersStrongSelectionBorder ? 1.5 : 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .sudylkoFocusSuppressed()
                }
            }
        }
    }
}
