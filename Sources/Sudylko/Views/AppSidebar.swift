import SwiftUI

struct AppSidebar: View {
    @Binding var activeSaveID: UUID?
    var liveTimerSaveID: UUID?
    var isInGame: Bool
    var saveSlots: [SaveSlotSummary]
    let liveTimer: PuzzleTimer
    var onNewGame: () -> Void
    var onSelectSave: (UUID) -> Void
    var onArchiveSave: (UUID) -> Void
    var onDeleteSave: (UUID) -> Void
    @Binding var savePendingArchive: SaveSlotSummary?
    @Binding var pendingProgressReset: ProgressResetKind?

    @State private var sidebarPanel: SidebarPanel = .games
    @State private var copyFeedbackMessage: String?
    @State private var copyFeedbackDismissTask: Task<Void, Never>?

    @AppStorage("sidebarDoneGamesCollapsed") private var doneGamesCollapsed = true
    @AppStorage("sidebarArchivedGamesCollapsed") private var archivedGamesCollapsed = false

    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue
    @Environment(\.isWindowFullscreen) private var isWindowFullscreen
    @Environment(\.puzzleFontStyle) private var puzzleFontStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appAccent) private var accent
    @Environment(\.appAccentProminentTint) private var prominentTint

    private var windowMaterial: WindowBackgroundMaterial {
        let stored = WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
        return stored.effective(whenFullscreen: isWindowFullscreen)
    }

    private var activeSaveSlots: [SaveSlotSummary] {
        saveSlots.filter { !$0.isArchived && $0.outcome != .won }
    }

    private var doneSaveSlots: [SaveSlotSummary] {
        saveSlots.filter { !$0.isArchived && $0.outcome == .won }
    }

    private var archivedSaveSlots: [SaveSlotSummary] {
        saveSlots.filter(\.isArchived)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarBrandHeader
            sidebarNewGameButton
            SidebarPanelPicker(selection: $sidebarPanel)
                .padding(.horizontal, SidebarMetrics.horizontalPadding)
                .padding(.bottom, 10)

            sidebarPanelContent
                .layoutPriority(1)

            keyboardShortcutsFooter
        }
        #if os(macOS)
        .frame(width: SidebarMetrics.width)
        #else
        .frame(maxWidth: .infinity)
        #endif
        .frame(maxHeight: .infinity, alignment: .top)
        .glassSidebar(accent: accent, colorScheme: colorScheme, material: windowMaterial)
        #if os(macOS)
        .safeAreaPadding(.vertical, SidebarMetrics.columnEdgePadding)
        #endif
        .id("sidebar-glass-\(colorScheme)-\(materialRaw)")
        #if os(macOS)
        .overlay(alignment: .bottom) {
            copyFeedbackOverlay
        }
        #endif
    }

    private var sidebarBrandHeader: some View {
        Text("Sudylko")
            .font(puzzleFontStyle.font(size: 28, weight: .bold))
            .padding(.horizontal, SidebarMetrics.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private var sidebarNewGameButton: some View {
        Button(action: onNewGame) {
            Text("New game")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominentTint)
        .controlSize(.large)
        .macOSTooltip(isInGame ? "Return to home and save this game" : "Start a new puzzle")
        .padding(.horizontal, SidebarMetrics.horizontalPadding)
        .padding(.bottom, 10)
    }

    private var keyboardShortcutsFooter: some View {
        Button {
            NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
        } label: {
            Label("Keyboard shortcuts", systemImage: "keyboard")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .macOSTooltip("View keyboard shortcuts")
        .padding(.horizontal, SidebarMetrics.horizontalPadding)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var copyFeedbackOverlay: some View {
        if let copyFeedbackMessage {
            CopyFeedbackToast(message: copyFeedbackMessage)
                .padding(.horizontal, SidebarMetrics.horizontalPadding)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var sidebarPanelContent: some View {
        switch sidebarPanel {
        case .games:
            savesList
        case .statistics:
            sidebarScroll {
                PlayerStatsView(
                    showsResetMenu: true,
                    onRequestReset: { pendingProgressReset = $0 }
                )
            }
        case .achievements:
            sidebarScroll {
                AchievementsListView(
                    showsResetMenu: true,
                    onRequestReset: { pendingProgressReset = $0 }
                )
            }
        }
    }

    private func sidebarScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SidebarMetrics.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
    }

    private var savesList: some View {
        List {
            Section {
                if activeSaveSlots.isEmpty {
                    Text("No saved games")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowInsets(SidebarMetrics.saveRowInsets)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(activeSaveSlots, id: \.id) { slot in
                        saveRow(slot)
                    }
                }
            } header: {
                sidebarSectionHeader("Existing games")
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
                    ) {
                        Button(role: .destructive) {
                            pendingProgressReset = .archivedGames
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .macOSTooltip("Delete all archived games")
                        .padding(.trailing, SidebarMetrics.horizontalPadding)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, SidebarMetrics.horizontalPadding, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
    }

    private func saveRow(_ slot: SaveSlotSummary) -> some View {
        let row = SaveRowView(
            slot: slot,
            staticElapsed: PuzzleTimer.format(slot.elapsedSeconds),
            showsLiveTimer: slot.id == liveTimerSaveID,
            liveTimer: liveTimer,
            onArchiveTap: { handleArchiveTap(slot) },
            onDeleteTap: slot.isArchived ? { onDeleteSave(slot.id) } : nil
        )
        return Group {
            if slot.id == liveTimerSaveID {
                row
            } else {
                row.equatable()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectSave(slot.id)
        }
        .contextMenu {
            Button {
                copySeedFromSlot(slot)
            } label: {
                Label("Copy number", systemImage: "doc.on.doc")
            }
        }
        .macOSTooltip("Right-click to copy puzzle number")
        .id(slot.id)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(SidebarMetrics.saveRowInsets)
        .listRowBackground(rowBackground(isSelected: activeSaveID == slot.id))
        .listRowSeparator(.hidden)
    }

    private func copySeedFromSlot(_ slot: SaveSlotSummary) {
        let seed = slot.puzzleSeed.clipboardText
        Clipboard.copy(seed)
        let difficulty = slot.puzzleSeed.difficulty.displayName
        withAnimation(.easeInOut(duration: 0.2)) {
            copyFeedbackMessage = "Copied \(seed) (\(difficulty)) to clipboard"
        }
        copyFeedbackDismissTask?.cancel()
        copyFeedbackDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    copyFeedbackMessage = nil
                }
            }
        }
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
        Color.clear
            .inspectorSegmentSelection(
                isSelected: isSelected,
                accent: accent,
                colorScheme: colorScheme,
                cornerRadius: InspectorLayout.controlSegmentCornerRadius
            )
            .padding(.horizontal, SidebarMetrics.selectionBackgroundHorizontalInset)
    }

    private func handleArchiveTap(_ slot: SaveSlotSummary) {
        if slot.outcome.requiresArchiveConfirmation {
            savePendingArchive = slot
        } else {
            onArchiveSave(slot.id)
        }
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        InspectorSectionLabel(title: title)
            .padding(.top, SidebarMetrics.sectionHeaderTopPadding)
            .padding(.bottom, SidebarMetrics.sectionHeaderBottomPadding)
    }

}
