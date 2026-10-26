import SwiftUI

/// Modals presented over the detail column. Requests are independent, so more than one can be
/// pending; `DetailModalOverlay` shows the first in declaration order.
struct DetailModals {
    var pendingArchiveSave: SaveSlotSummary?
    var pendingProgressReset: ProgressResetKind?
    var confirmsGameArchive = false
    var confirmsGameRestart = false
    var customPuzzle: CustomPuzzleDraft?
    var showsKeyboardShortcuts = false
    var confirmsDeleteAllSaves = false

    var isPresented: Bool {
        pendingArchiveSave != nil
            || pendingProgressReset != nil
            || confirmsGameArchive
            || confirmsGameRestart
            || customPuzzle != nil
            || showsKeyboardShortcuts
            || confirmsDeleteAllSaves
    }

    mutating func dismissAll() {
        self = DetailModals()
    }
}

struct CustomPuzzleDraft {
    var seedInput: String
    var difficulty: GameDifficulty
}

struct DetailModalOverlay: View {
    @Binding var modals: DetailModals
    @ObservedObject var session: GameSessionModel
    let customPuzzlePrep: CustomPuzzlePrepModel
    let colorScheme: ColorScheme
    let onStartCustomPuzzle: () -> Void

    var body: some View {
        if let slot = modals.pendingArchiveSave {
            SudylkoDetailModalOverlay(onDismiss: { modals.pendingArchiveSave = nil }) {
                ArchiveSaveModal(
                    gameTitle: slot.gameTitle,
                    onCancel: { modals.pendingArchiveSave = nil },
                    onArchive: {
                        modals.pendingArchiveSave = nil
                        session.archiveSave(id: slot.id)
                    }
                )
            }
        } else if let kind = modals.pendingProgressReset {
            SudylkoDetailModalOverlay(onDismiss: { modals.pendingProgressReset = nil }) {
                ProgressResetModal(
                    kind: kind,
                    onCancel: { modals.pendingProgressReset = nil },
                    onConfirm: {
                        session.performProgressReset(kind)
                        modals.pendingProgressReset = nil
                    }
                )
            }
        } else if modals.confirmsGameArchive {
            SudylkoDetailModalOverlay(onDismiss: { modals.confirmsGameArchive = false }) {
                gameArchiveModal
            }
        } else if modals.confirmsGameRestart {
            SudylkoDetailModalOverlay(onDismiss: { modals.confirmsGameRestart = false }) {
                gameRestartModal
            }
        } else if let draft = Binding($modals.customPuzzle) {
            SudylkoDetailModalOverlay(onDismiss: { modals.customPuzzle = nil }) {
                CustomPuzzleSheet(
                    prep: customPuzzlePrep,
                    seedInput: draft.seedInput,
                    difficulty: draft.difficulty,
                    onCancel: { modals.customPuzzle = nil },
                    onStart: onStartCustomPuzzle
                )
                .onDisappear { customPuzzlePrep.reset() }
            }
        } else if modals.showsKeyboardShortcuts {
            // iOS never sets this flag; ContentView presents shortcuts as a system sheet there.
            #if os(macOS)
            SudylkoDetailModalOverlay(onDismiss: { modals.showsKeyboardShortcuts = false }) {
                KeyboardShortcutsView()
                    .environment(\.colorScheme, colorScheme)
            }
            #endif
        } else if modals.confirmsDeleteAllSaves {
            SudylkoDetailModalOverlay(onDismiss: { modals.confirmsDeleteAllSaves = false }) {
                DeleteAllSavesModal(
                    onCancel: { modals.confirmsDeleteAllSaves = false },
                    onDelete: {
                        modals.confirmsDeleteAllSaves = false
                        SaveLoadWork.deleteAll()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var gameArchiveModal: some View {
        if let game = session.game, let saveID = session.activeSaveID {
            ArchiveSaveModal(
                gameTitle: "Game \(game.puzzleSeed.gameNumberLabel)",
                onCancel: { modals.confirmsGameArchive = false },
                onArchive: {
                    modals.confirmsGameArchive = false
                    session.archiveSave(id: saveID)
                }
            )
        }
    }

    @ViewBuilder
    private var gameRestartModal: some View {
        if let game = session.game {
            RestartPuzzleModal(
                onCancel: { modals.confirmsGameRestart = false },
                onRestart: {
                    modals.confirmsGameRestart = false
                    session.restartCurrentPuzzle(game: game)
                }
            )
        }
    }
}
