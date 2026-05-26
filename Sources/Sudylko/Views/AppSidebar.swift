import SwiftUI

struct AppSidebar: View {
    @Binding var activeSaveID: UUID?
    var isInGame: Bool
    var saveSlots: [SaveSlotSummary]
    var saveSlotsRevision: Int
    @ObservedObject var liveTimer: PuzzleTimer
    var onNewGame: () -> Void
    var onSelectSave: (UUID) -> Void
    var onArchiveSave: (UUID) -> Void

    @State private var savePendingArchive: SaveSlotSummary?

    @AppStorage("sidebarDoneGamesCollapsed") private var doneGamesCollapsed = true
    @AppStorage("sidebarArchivedGamesCollapsed") private var archivedGamesCollapsed = false

    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.isWindowFullscreen) private var isWindowFullscreen
    @Environment(\.digitFontStyle) private var digitFontStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent
    @Environment(\.appAccentProminentTint) private var prominentTint

    private var windowMaterial: WindowBackgroundMaterial {
        let stored = WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
        return stored.effective(whenFullscreen: isWindowFullscreen)
    }

    private var activeSaveSlots: [SaveSlotSummary] {
        saveSlots.filter { !$0.isArchived && !$0.isComplete }
    }

    private var doneSaveSlots: [SaveSlotSummary] {
        saveSlots.filter { !$0.isArchived && $0.isComplete }
    }

    private var archivedSaveSlots: [SaveSlotSummary] {
        saveSlots.filter(\.isArchived)
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
            archiveDialogTitle,
            isPresented: archiveDialogPresented,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) {
                if let id = savePendingArchive?.id {
                    onArchiveSave(id)
                }
                savePendingArchive = nil
            }
            Button("Cancel", role: .cancel) {
                savePendingArchive = nil
            }
        } message: {
            Text("This game moves to Archived games. You can open it from there later.")
        }
    }

    private var savesList: some View {
        List {
            Section("Existing games") {
                if activeSaveSlots.isEmpty {
                    Text("No saved games")
                        .foregroundStyle(.secondary)
                        .listRowInsets(SidebarMetrics.saveRowInsets)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(activeSaveSlots, id: \.id) { slot in
                        saveRow(slot)
                    }
                }
            }

            if !doneSaveSlots.isEmpty {
                Section {
                    if !doneGamesCollapsed {
                        ForEach(doneSaveSlots, id: \.id) { slot in
                            saveRow(slot)
                        }
                    }
                } header: {
                    CollapsibleSidebarSectionHeader(
                        title: "Done games",
                        isCollapsed: $doneGamesCollapsed
                    )
                }
            }

            if !archivedSaveSlots.isEmpty {
                Section {
                    if !archivedGamesCollapsed {
                        ForEach(archivedSaveSlots, id: \.id) { slot in
                            saveRow(slot)
                        }
                    }
                } header: {
                    CollapsibleSidebarSectionHeader(
                        title: "Archived games",
                        isCollapsed: $archivedGamesCollapsed
                    )
                }
            }
        }
        .id(saveSlotsRevision)
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, SidebarMetrics.horizontalPadding, for: .scrollContent)
        .frame(maxHeight: .infinity)
    }

    private func saveRow(_ slot: SaveSlotSummary) -> some View {
        Button {
            onSelectSave(slot.id)
        } label: {
            SaveRowView(
                slot: slot,
                displayTime: displayTime(for: slot),
                onArchiveTap: { savePendingArchive = slot }
            )
        }
        .buttonStyle(.plain)
        .id(slot.id)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(SidebarMetrics.saveRowInsets)
        .listRowBackground(rowBackground(isSelected: activeSaveID == slot.id))
        .listRowSeparator(.hidden)
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

    private var archiveDialogTitle: String {
        if let slot = savePendingArchive {
            return "Archive \(slot.gameTitle)?"
        }
        return "Archive save?"
    }

    private var archiveDialogPresented: Binding<Bool> {
        Binding(
            get: { savePendingArchive != nil },
            set: { if !$0 { savePendingArchive = nil } }
        )
    }

    private func displayTime(for slot: SaveSlotSummary) -> String {
        if slot.id == activeSaveID, liveTimer.isRunning || liveTimer.isPaused {
            return liveTimer.formattedElapsed
        }
        return PuzzleTimer.format(slot.elapsedSeconds)
    }
}

/// Collapsible header for Done / Archived sections; matches plain `Section("…")` title placement.
private struct CollapsibleSidebarSectionHeader: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isCollapsed)
    }
}
