import SwiftUI

struct PuzzleFontPickerView: View {
    @Binding var fontStyleRaw: String
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private var selected: PuzzleFontStyle {
        PuzzleFontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
            FormSectionLabel(title: "Puzzle font")

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(PuzzleFontStyle.allCases) { style in
                    Button {
                        fontStyleRaw = style.rawValue
                    } label: {
                        Text("12")
                            .font(style.font(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .inspectorSegmentSelection(
                                isSelected: selected == style,
                                accent: accent,
                                colorScheme: colorScheme,
                                cornerRadius: ThemeMetrics.controlCornerRadius
                            )
                            .overlay {
                                if selected != style {
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
            }
        }
    }
}
