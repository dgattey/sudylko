import SwiftUI

struct SettingsPopoverView: View {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("accentColor") private var accentRaw = AppAccentColor.blue.rawValue
    @AppStorage("puzzleFontStyle") private var fontStyleRaw = PuzzleFontStyle.rounded.rawValue
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false
    @AppStorage("impossibleMode") private var impossibleMode = false
    @AppStorage("hideNumbersWhenInactive") private var hideNumbersWhenInactive = true

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.groupSpacing) {
            AppearancePickerView(appearanceRaw: $appearanceRaw)
            WindowBackgroundMaterialControl()

            VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
                FormSectionLabel(title: "Display")

                Toggle(isOn: $hideNumbersWhenInactive) {
                    FormToggleCaption(
                        title: "Hide numbers when inactive",
                        caption: "Blanks the board when Sudylko is not the focused app."
                    )
                }
                .sudylkoFocusSuppressed()
            }

            AccentColorPickerView(accentRaw: $accentRaw)
            PuzzleFontPickerView(fontStyleRaw: $fontStyleRaw)

            VStack(alignment: .leading, spacing: FormLayout.sectionSpacing) {
                FormSectionLabel(title: "Gameplay")

                Toggle("Reveal mistakes immediately", isOn: $revealMistakesImmediately)
                    .font(.body)
                    .sudylkoFocusSuppressed()

                Toggle(isOn: $impossibleMode) {
                    FormToggleCaption(
                        title: "Impossible mode",
                        caption: "Ends the game immediately when you enter a wrong number."
                    )
                }
                .sudylkoFocusSuppressed()
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}
