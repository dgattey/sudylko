import Observation

/// App-wide state the menu bar and the Settings window share with the game window.
@Observable
@MainActor
final class AppCommandState {
    var canUndo = false
    var canRedo = false
    var canDelete = false
    /// The running puzzle auto-pauses while Settings is open.
    var isSettingsOpen = false

    func sync(with game: GameViewModel?) {
        canUndo = game?.canUndo ?? false
        canRedo = game?.canRedo ?? false
        canDelete = game?.canDelete ?? false
    }
}
