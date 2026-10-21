import SwiftUI

/// Detail-column toolbar: game controls while a puzzle is open, otherwise the home actions.
struct DetailToolbar: ToolbarContent {
    /// Outcome of the open puzzle; nil on the home screen.
    let gameOutcome: PuzzleOutcome?
    let timer: PuzzleTimer
    let isArchived: Bool
    let colorScheme: ColorScheme
    @Binding var showSettings: Bool
    let onGoHome: () -> Void
    let onArchive: () -> Void
    let onRestart: () -> Void
    let onToggleSidebar: () -> Void

    var body: some ToolbarContent {
        if let gameOutcome {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.left", action: onGoHome)
                    .font(.body)
                    .help("Back to home and save this game")
            }
            ToolbarItem(placement: .principal) {
                GameTimerBar(
                    timer: timer,
                    isPuzzleEnded: gameOutcome.isEnded,
                    endedLabel: Self.endedLabel(for: gameOutcome),
                    endedLabelColor: Self.endedLabelColor(for: gameOutcome)
                )
                .fixedSize()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if !isArchived {
                    Button("Archive", systemImage: "archivebox", role: .destructive, action: onArchive)
                        .font(.body)
                        .help("Archive this saved game")
                }
                Button("Restart", systemImage: "arrow.counterclockwise", action: onRestart)
                    .font(.body)
                    .help("Restart this puzzle from the beginning")
                settingsButton
            }
        } else {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button("Saves", systemImage: "sidebar.left", action: onToggleSidebar)
            }
            #else
            ToolbarItem {
                Spacer()
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                settingsButton
            }
        }
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape") {
            showSettings = true
        }
        .font(.body)
        .help("Open appearance and puzzle settings")
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
            SettingsPopoverView()
                .environment(\.colorScheme, colorScheme)
                .preferredColorScheme(colorScheme)
        }
    }

    private static func endedLabel(for outcome: PuzzleOutcome) -> String? {
        switch outcome {
        case .playing: nil
        case .won: "Done"
        case .lost: "Lost"
        }
    }

    private static func endedLabelColor(for outcome: PuzzleOutcome) -> Color {
        switch outcome {
        case .playing: .primary
        case .won: .green
        case .lost: .red
        }
    }
}
