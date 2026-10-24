import DylUI
import SudylkoShared
import SwiftUI

/// The Settings window on macOS and the Settings sheet on iOS. The running puzzle pauses while it's open.
struct SudylkoSettings: View {
    let appAccent: AppAccentModel
    let appCommands: AppCommandState

    var body: some View {
        SettingsView(sections: Self.sections)
            .appAccentPropagation(appAccent)
            .environment(\.colorScheme, appAccent.resolvedColorScheme)
            .preferredColorScheme(appAccent.resolvedColorScheme)
            .onAppear { appCommands.isSettingsOpen = true }
            .onDisappear { appCommands.isSettingsOpen = false }
    }

    @MainActor
    private static var sections: [SettingsSection] {
        var app = [
            SettingsPage("Appearance", systemImage: "paintbrush") { AppearanceSettings() },
            SettingsPage("Gameplay", systemImage: "square.grid.3x3") { GameplaySettings() },
        ]
        #if os(macOS)
        app.append(SettingsPage("Software Updates", systemImage: "arrow.down.circle") { UpdatesSection() })
        #endif
        app.append(SettingsPage("About", systemImage: "info.circle") { AboutSection() })
        return [SettingsSection(pages: app)]
    }
}

private struct AppearanceSettings: View {
    @AppStorage(SudylkoPreferenceKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SudylkoPreferenceKey.accent) private var accentRaw = AppAccentColor.blue.rawValue
    @AppStorage("puzzleFontStyle") private var fontStyleRaw = PuzzleFontStyle.rounded.rawValue
    @AppStorage("hideNumbersWhenInactive") private var hideNumbersWhenInactive = true

    var body: some View {
        Section {
            AppearancePickerView(appearanceRaw: $appearanceRaw)
            AccentColorPickerView(accentRaw: $accentRaw)
            WindowBackgroundMaterialControl()
        }
        Section {
            PuzzleFontPickerView(fontStyleRaw: $fontStyleRaw)
        }
        Section {
            Toggle(isOn: $hideNumbersWhenInactive) {
                FormToggleCaption(
                    title: "Hide numbers when inactive",
                    caption: "Blanks the board when Sudylko is not the focused app."
                )
            }
            .sudylkoFocusSuppressed()
        }
    }
}

private struct GameplaySettings: View {
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false
    @AppStorage("impossibleMode") private var impossibleMode = false

    var body: some View {
        Section {
            Toggle("Reveal mistakes immediately", isOn: $revealMistakesImmediately)
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
}
