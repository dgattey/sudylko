import Combine
import Foundation

@MainActor
final class AppCommandState: ObservableObject {
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var canDelete = false

    func sync(with game: GameViewModel?) {
        canUndo = game?.canUndo ?? false
        canRedo = game?.canRedo ?? false
        canDelete = game?.canDelete ?? false
    }
}
