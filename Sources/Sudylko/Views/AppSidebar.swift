import SwiftUI

struct AppSidebar: View {
    @Binding var activeSaveID: UUID?
    var isInGame: Bool
    var saveSlots: [SaveSlotSummary]
    @ObservedObject var liveTimer: PuzzleTimer
    var onNewGame: () -> Void
    var onSelectSave: (UUID) -> Void
    var onDeleteSave: (UUID) -> Void

    @State private var savePendingDeletion: SaveSlotSummary?

    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.digitFontStyle) private var digitFontStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent
    @Environment(\.appAccentProminentTint) private var prominentTint

    private var windowMaterial: WindowBackgroundMaterial {
        WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sudylko")
                .font(digitFontStyle.font(size: 28, weight: .bold))
                .padding(.horizontal, SidebarMetrics.horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Button(action: onNewGame) {
                Text("New game")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(prominentTint)
            .controlSize(.large)
            .macOSTooltip(isInGame ? "Return to home and save this game" : "Start a new puzzle")
            .padding(.horizontal, SidebarMetrics.horizontalPadding)
            .padding(.bottom, 10)

            savesList

            Button {
                NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
            } label: {
                Label("Keyboard shortcuts", systemImage: "keyboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .macOSTooltip("View keyboard shortcuts")
            .padding(.horizontal, SidebarMetrics.horizontalPadding)
            .padding(.vertical, 12)
        }
        .frame(width: SidebarMetrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassSidebar(accent: accent, colorScheme: colorScheme, material: windowMaterial)
        .id("sidebar-glass-\(colorScheme)-\(materialRaw)")
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: deleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = savePendingDeletion?.id {
                    onDeleteSave(id)
                }
                savePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                savePendingDeletion = nil
            }
        } message: {
            Text("This saved game will be permanently removed.")
        }
    }

    private var savesList: some View {
        List {
            Section("Existing games") {
                if saveSlots.isEmpty {
                    Text("No saved games")
                        .foregroundStyle(.secondary)
                        .listRowInsets(SidebarMetrics.saveRowInsets)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(saveSlots, id: \.id) { slot in
                        SaveRowView(
                            slot: slot,
                            displayTime: displayTime(for: slot),
                            onDeleteTap: { savePendingDeletion = slot }
                        )
                        .id(slot.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectSave(slot.id)
                        }
                        .listRowInsets(SidebarMetrics.saveRowInsets)
                        .listRowBackground(
                            rowBackground(isSelected: activeSaveID == slot.id)
                        )
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, SidebarMetrics.horizontalPadding, for: .scrollContent)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.selectionFill(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(accent.selectionBorder(for: colorScheme), lineWidth: 1)
                }
                .padding(.horizontal, SidebarMetrics.selectionBackgroundHorizontalInset)
        } else {
            Color.clear
        }
    }

    private var deleteDialogTitle: String {
        if let slot = savePendingDeletion {
            return "Delete \(slot.gameTitle)?"
        }
        return "Delete save?"
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(
            get: { savePendingDeletion != nil },
            set: { if !$0 { savePendingDeletion = nil } }
        )
    }

    private func displayTime(for slot: SaveSlotSummary) -> String {
        if slot.id == activeSaveID, liveTimer.isRunning || liveTimer.isPaused {
            return liveTimer.formattedElapsed
        }
        return PuzzleTimer.format(slot.elapsedSeconds)
    }
}
