import SwiftUI

struct AccentColorPickerView: View {
    @Binding var accentRaw: String

    private var selected: AppAccentColor {
        AppAccentColor(rawValue: accentRaw) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent color")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(AppAccentColor.allCases) { accent in
                    Button {
                        accentRaw = accent.rawValue
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if selected == accent {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(.plain)
                    .sudylkoFocusSuppressed()
                }
            }
        }
    }
}
