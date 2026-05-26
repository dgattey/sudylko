import SwiftUI

struct SettingsPopoverView: View {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("accentColor") private var accentRaw = AppAccentColor.blue.rawValue
    @AppStorage("digitFontStyle") private var fontStyleRaw = DigitFontStyle.rounded.rawValue
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppearancePickerView(appearanceRaw: $appearanceRaw)
            WindowBackgroundMaterialControl()
            AccentColorPickerView(accentRaw: $accentRaw)
            DigitFontPickerView(fontStyleRaw: $fontStyleRaw)

            VStack(alignment: .leading, spacing: 8) {
                Text("Mistakes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Toggle("Reveal immediately", isOn: $revealMistakesImmediately)
                    .font(.subheadline)
                    .sudylkoFocusSuppressed()
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
