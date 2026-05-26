import SwiftUI

struct SettingsPopoverView: View {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("accentColor") private var accentRaw = AppAccentColor.blue.rawValue
    @AppStorage("digitFontStyle") private var fontStyleRaw = DigitFontStyle.rounded.rawValue
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false
    @AppStorage("impossibleMode") private var impossibleMode = false
    @AppStorage("hideNumbersWhenInactive") private var hideNumbersWhenInactive = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppearancePickerView(appearanceRaw: $appearanceRaw)
            WindowBackgroundMaterialControl()

            VStack(alignment: .leading, spacing: 8) {
                Text("Display")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Toggle(isOn: $hideNumbersWhenInactive) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hide numbers when inactive")
                            .font(.subheadline)
                        Text("Blanks the board when Sudylko is not the focused app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .sudylkoFocusSuppressed()
            }

            AccentColorPickerView(accentRaw: $accentRaw)
            DigitFontPickerView(fontStyleRaw: $fontStyleRaw)

            VStack(alignment: .leading, spacing: 8) {
                Text("Gameplay")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Toggle("Reveal mistakes immediately", isOn: $revealMistakesImmediately)
                    .font(.subheadline)
                    .sudylkoFocusSuppressed()

                Toggle(isOn: $impossibleMode) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Impossible mode")
                            .font(.subheadline)
                        Text("Ends the game immediately when you enter a wrong number.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .sudylkoFocusSuppressed()
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
