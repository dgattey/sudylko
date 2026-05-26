import Combine
import Foundation

@MainActor
final class AppCommandState: ObservableObject {
    static weak var live: AppCommandState?

    @Published var canUndo = false
    @Published var canRedo = false
    @Published var canDelete = false

    func sync(with game: GameViewModel?) {
        canUndo = game?.canUndo ?? false
        canRedo = game?.canRedo ?? false
        canDelete = game?.canDelete ?? false
    }
}
