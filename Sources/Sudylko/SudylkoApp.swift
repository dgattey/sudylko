#if os(macOS)
import DylUI
import SwiftUI

@main
struct SudylkoApp: App {
    @NSApplicationDelegateAdaptor(SudylkoAppDelegate.self) private var appDelegate
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
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .undoRedo) {
                Button {
                    NotificationCenter.default.post(name: .undo, object: nil)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!appCommands.canUndo)

                Button {
                    NotificationCenter.default.post(name: .redo, object: nil)
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!appCommands.canRedo)
            }
            CommandGroup(after: .undoRedo) {
                Button {
                    NotificationCenter.default.post(name: .deleteCell, object: nil)
                } label: {
                    Label("Delete", systemImage: "delete.backward")
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!appCommands.canDelete)
            }
            CommandGroup(after: .sidebar) {
                Button {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                } label: {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
                .keyboardShortcut("?", modifiers: .shift)
            }
        }
        SettingsWindow(palette: appAccent.palette) {
            SudylkoSettings(appAccent: appAccent, appCommands: appCommands)
        }
    }
}
#endif
