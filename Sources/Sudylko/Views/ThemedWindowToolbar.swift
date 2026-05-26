import SwiftUI

extension View {
    /// Keeps the unified title bar visually transparent (home and in-game).
    func hiddenWindowToolbar() -> some View {
        toolbarBackground(.hidden, for: .windowToolbar)
    }
}
