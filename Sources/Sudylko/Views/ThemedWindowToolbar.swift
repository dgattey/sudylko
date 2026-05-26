import SwiftUI

extension View {
    /// Keeps the unified title bar visually transparent (home and in-game).
    func hiddenWindowToolbar() -> some View {
        #if os(macOS)
        toolbarBackground(.hidden, for: .windowToolbar)
        #else
        self
        #endif
    }
}
