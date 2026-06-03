#if os(macOS)
import SwiftUI
import SudylkoShared

@main
struct SudylkoApp: App {
    @NSApplicationDelegateAdaptor(SudylkoAppDelegate.self) private var appDelegate
    @StateObject private var appCommands = AppCommandState()
    @StateObject private var appAccent = AppAccentModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCommands)
                .environmentObject(appAccent)
                .appAccentPropagation(appAccent)
        }
        .defaultSize(width: 820, height: 720)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
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
                    EditMenuDeleteController.shared.deleteSelectedCell(nil)
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
                    HelpMenuShortcutController.shared.showKeyboardShortcuts(nil)
                } label: {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
                .keyboardShortcut("?", modifiers: .shift)
            }
        }
    }
}
#endif
