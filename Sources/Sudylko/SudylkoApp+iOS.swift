#if os(iOS)
import SwiftUI
import SudylkoShared

@main
struct SudylkoApp: App {
    @StateObject private var appCommands = AppCommandState()
    @StateObject private var appAccent = AppAccentModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCommands)
                .environmentObject(appAccent)
                .appAccentPropagation(appAccent)
        }
        #if DEBUG
        .commands {
            CommandMenu("Debug") {
                Button("Seed done game") {
                    Task { @MainActor in
                        _ = GameSaveStore.debugSeedCompletedGame()
                    }
                }
                Button("Delete all saves…") {
                    GameSaveStore.deleteAll()
                }
            }
        }
        #endif
    }
}
#endif
