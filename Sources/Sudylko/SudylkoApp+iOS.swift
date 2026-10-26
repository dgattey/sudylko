#if os(iOS)
import DylUI
import SwiftUI

@main
struct SudylkoApp: App {
    @State private var appCommands = AppCommandState()
    @State private var appAccent: AppAccentModel
    @State private var session: GameSessionModel

    init() {
        let appAccent = AppAccentModel()
        _appAccent = State(initialValue: appAccent)
        _session = State(initialValue: GameSessionModel(appAccent: appAccent))
    }

    var body: some Scene {
        AppWindow("Sudylko", palette: appAccent.palette, defaultSize: CGSize(width: 820, height: 720)) {
            ContentView(session: session)
                .environment(appCommands)
                .environment(appAccent)
                .appAccentPropagation(appAccent)
        } commands: {
            #if DEBUG
            CommandMenu("Debug") {
                Button("Seed done game") {
                    SaveLoadWork.debugSeedCompletedGame()
                }
                Button("Delete all saves…") {
                    NotificationCenter.default.post(
                        name: .requestDeleteAllSavesConfirmation,
                        object: nil
                    )
                }
            }
            #endif
        }
    }
}
#endif
