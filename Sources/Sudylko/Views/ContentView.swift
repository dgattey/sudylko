import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @EnvironmentObject private var appCommands: AppCommandState
#if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
#endif
    @EnvironmentObject private var appAccent: AppAccentModel
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("puzzleFontStyle") private var fontStyleRaw = PuzzleFontStyle.rounded.rawValue
    @AppStorage("lastDifficulty") private var lastDifficultyRaw = GameDifficulty.medium.rawValue
    @AppStorage("lastFocusedSaveID") private var lastFocusedSaveIDString = ""
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false
    @AppStorage("impossibleMode") private var impossibleMode = false
    @State private var game: GameViewModel?
    @State private var isAppActive = true
    @State private var isWindowMiniaturized = false
    @State private var isWindowFullscreen = false
    @State private var autoPausedForInactive = false
    @State private var activeSaveID: UUID?
    @State private var seedInput = ""
    @State private var seedSheetDifficulty: GameDifficulty = .medium
    @State private var showSeedSheet = false
    @State private var showSettings = false
    @State private var showKeyboardShortcuts = false
    @State private var showGameArchiveConfirmation = false
    @State private var showGameRestartConfirmation = false
    @State private var savePendingArchive: SaveSlotSummary?
    @State private var pendingProgressReset: ProgressResetKind?
    #if DEBUG
    @State private var showDeleteAllSavesConfirmation = false
    #endif
    #if os(iOS)
    @State private var showSavesSheet = false
    #else
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif
    @StateObject private var puzzleTimer = PuzzleTimer()
    @StateObject private var customPuzzlePrep = CustomPuzzlePrepModel()
    @State private var randomPuzzlePrep = RandomPuzzlePrepCache()
    /// Tracks macOS system appearance when `appearanceMode == .system` (updated via distributed notification).
    @State private var systemColorScheme = AppearanceMode.systemColorScheme()
    @State private var saveSlots: [SaveSlotSummary] = []
    /// Avoids re-reading the active save from disk when persisting on switch.
    @State private var activeSaveMetadata: SavePersistMetadata?
    @State private var celebrationQueue: [AchievementID] = []
    @State private var activeCelebration: AchievementID?
    @State private var loadingMessage: String?
    @State private var isPuzzleEndBannerVisible = false
    @State private var saveLoadTask: Task<Void, Never>?
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var puzzleFont: PuzzleFontStyle {
        PuzzleFontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    private var resolvedColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme(system: systemColorScheme)
    }

    private var isInGame: Bool {
        game != nil && activeSaveID != nil
    }

    /// Save the live timer reflects; nil while switching or before restore finishes.
    private var liveTimerSaveID: UUID? {
        guard isInGame,
              let id = activeSaveID,
              lastFocusedSaveIDString == id.uuidString
        else { return nil }
        return id
    }

    #if os(macOS)
    private var showsSidebar: Bool {
        columnVisibility != .detailOnly
    }

    private var macWindowMinimumSize: CGSize {
        WindowLayoutMetrics.minimumSize(
            showsSidebar: showsSidebar,
            showsHomeInspector: false
        )
    }
    #endif

    private var lastFocusedDifficulty: GameDifficulty {
        GameDifficulty(rawValue: lastDifficultyRaw) ?? .medium
    }

    var body: some View {
        appChrome
    }

    private var keyboardShortcutsSheet: some View {
        #if os(iOS)
        NavigationStack {
            KeyboardShortcutsView()
                .navigationTitle("Keyboard shortcuts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showKeyboardShortcuts = false
                        }
                    }
                }
        }
        .environment(\.colorScheme, resolvedColorScheme)
        #else
        KeyboardShortcutsView()
            .environment(\.colorScheme, resolvedColorScheme)
        #endif
    }

    /// Wraps all window UI including sheets so accent `tint` is not scoped only to `rootSplitView`.
    private var appChrome: some View {
        appChromeWithLifecycle
    }

    private var appChromeWithSheets: some View {
        rootChrome { platformRootCore }
            #if os(iOS)
            .sheet(isPresented: $showSavesSheet) { savesSheet }
            #endif
    }

    @ViewBuilder
    private var platformRootCore: some View {
        #if os(iOS)
        NavigationStack {
            detailColumn
        }
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(SidebarMetrics.width)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }

    #if os(iOS)
    private var savesSheet: some View {
        NavigationStack {
            sidebar
                .navigationTitle("Saves")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showSavesSheet = false
                        }
                    }
                }
        }
    }
    #endif

    @ViewBuilder
    private func rootChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
        #if os(macOS)
            .frame(
                minWidth: macWindowMinimumSize.width,
                minHeight: macWindowMinimumSize.height
            )
        #endif
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .hiddenWindowToolbar()
            .appBackground()
            .environment(\.colorScheme, resolvedColorScheme)
            .environment(\.puzzleFontStyle, puzzleFont)
            .sudylkoAppTypography()
            .environment(\.isAppActive, isAppActive)
            .environment(\.isWindowFullscreen, isWindowFullscreen)
            .preferredColorScheme(resolvedColorScheme)
        #if os(macOS)
            .background(WindowConfigurator(
                appearanceMode: appearanceMode,
                minimumWindowSize: macWindowMinimumSize,
                isAppActive: $isAppActive,
                isWindowMiniaturized: $isWindowMiniaturized,
                isWindowFullscreen: $isWindowFullscreen
            ))
        #endif
        #if os(iOS)
            .onChange(of: scenePhase) { _, phase in
                let active = phase == .active
                if isAppActive != active {
                    isAppActive = active
                }
                if phase == .active {
                    handleSystemThemeDidChange()
                }
            }
        #endif
            .onChange(of: appearanceRaw) { _, _ in refreshAppearanceFromSettings() }
            .onChange(of: isAppActive) { _, active in handleAppActiveChange(active) }
            .onChange(of: showSettings) { _, _ in
                scheduleAutoPauseInterruptUpdate()
            }
            .onChange(of: isWindowMiniaturized) { _, _ in
                scheduleAutoPauseInterruptUpdate()
            }
            .onChange(of: activeSaveID) { oldID, newID in
                handleActiveSaveIDChange(from: oldID, to: newID)
                updateDockIcon()
            }
            .onChange(of: isInGame) { _, inGame in
                if inGame {
                    #if os(iOS)
                    showSavesSheet = false
                    #endif
                }
            }
            .onChange(of: puzzleTimer.isPaused) { _, _ in
                persistGameplaySession()
                updateDockIcon()
            }
            .onChange(of: puzzleTimer.formattedElapsed) { _, _ in
                if activeSaveID != nil { updateDockIcon() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sudylkoSystemThemeDidChange)) { _ in
                handleSystemThemeDidChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                toggleSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                toggleSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
                showKeyboardShortcuts = true
            }
        #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .requestDeleteAllSavesConfirmation)) { _ in
                showDeleteAllSavesConfirmation = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugAchievementUnlocked)) { notification in
                guard let id = notification.object as? AchievementID else { return }
                enqueueCelebrations([id])
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugTriggerPulse)) { notification in
                guard let kind = notification.object as? DebugPulseKind else { return }
                switch kind {
                case .puzzleComplete:
                    game?.debugTriggerPuzzleCompletePulse()
                case .finishedRow:
                    game?.debugTriggerFinishedRowPulse()
                case .finishedColumn:
                    game?.debugTriggerFinishedColumnPulse()
                case .finishedBox:
                    game?.debugTriggerFinishedBoxPulse()
                case .finishedDigit:
                    game?.debugTriggerFinishedDigitPulse()
                }
            }
        #endif
            .onReceive(NotificationCenter.default.publisher(for: .savesDidChange), perform: handleSavesDidChange)
            .onReceive(NotificationCenter.default.publisher(for: .undo)) { _ in
                game?.undo()
                appCommands.sync(with: game)
            }
            .onReceive(NotificationCenter.default.publisher(for: .redo)) { _ in
                game?.redo()
                appCommands.sync(with: game)
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteCell)) { _ in
                game?.keyboardClearSelected()
                appCommands.sync(with: game)
            }
            .onChange(of: game?.canUndo) { _, _ in appCommands.sync(with: game) }
            .onChange(of: game?.canRedo) { _, _ in appCommands.sync(with: game) }
            .onChange(of: game?.canDelete) { _, _ in appCommands.sync(with: game) }
    }

    private var appChromeWithLifecycle: some View {
        appChromeWithSheets
            .onAppear {
                AppCommandState.live = appCommands
                appAccent.refresh()
                performInitialSetup()
            }
            .onChange(of: game?.outcome) { old, new in
                handleOutcomeChange(from: old, to: new)
                if new == .won || new == .lost {
                    isPuzzleEndBannerVisible = true
                } else if new == .playing {
                    isPuzzleEndBannerVisible = false
                }
            }
            .onChange(of: game?.puzzleRevision) { _, _ in
                persistPuzzleProgress()
            }
            .onChange(of: game?.sessionRevision) { _, _ in
                persistSessionState()
            }
            #if os(macOS)
            .onChange(of: appAccent.accent) { _, _ in
                DockIconRenderer.invalidateCache()
                updateDockIcon()
            }
            .onChange(of: appAccent.resolvedColorScheme) { _, _ in
                DockIconRenderer.invalidateCache()
                updateDockIcon()
            }
            #endif
            .onChange(of: revealMistakesImmediately) { _, _ in
                applyGameplaySettingsToActiveGame()
            }
            .onChange(of: impossibleMode) { _, _ in
                applyGameplaySettingsToActiveGame()
            }
    }

    /// Loading blocks win/loss; end banner is optional until dismissed (sidebar stays usable).
    private var gameOverlayPhase: GameOverlayPhase? {
        if let loadingMessage {
            return .loading(loadingMessage)
        }
        guard isPuzzleEndBannerVisible else { return nil }
        switch game?.outcome {
        case .won:
            return .puzzleEnd(PuzzleEndBannerView.Kind.won)
        case .lost:
            return .puzzleEnd(PuzzleEndBannerView.Kind.lost)
        default:
            return nil
        }
    }

    private func dismissPuzzleEndBanner() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPuzzleEndBannerVisible = false
        }
    }

    private var seedSheet: some View {
        CustomPuzzleSheet(
            prep: customPuzzlePrep,
            seedInput: $seedInput,
            difficulty: $seedSheetDifficulty,
            onCancel: { showSeedSheet = false },
            onStart: startFromPreparedCustomPuzzle
        )
        .onDisappear { customPuzzlePrep.reset() }
    }

    private func startFromPreparedCustomPuzzle() {
        guard let seed = customPuzzlePrep.readySeed,
              let template = customPuzzlePrep.readyTemplate else { return }
        showSeedSheet = false
        pauseAndPersistOutgoingGame()
        lastDifficultyRaw = seed.difficulty.rawValue
        beginNewGame(
            puzzleSeed: seed,
            startedFromCustomSeed: true,
            preparedTemplate: template
        )
    }

    @ViewBuilder
    private var gameArchiveModal: some View {
        if let game, let saveID = activeSaveID {
            ArchiveSaveModal(
                gameTitle: "Game \(game.puzzleSeed.gameNumberLabel)",
                onCancel: { showGameArchiveConfirmation = false },
                onArchive: {
                    showGameArchiveConfirmation = false
                    archiveSave(id: saveID)
                }
            )
        }
    }

    @ViewBuilder
    private var gameRestartModal: some View {
        if let game {
            RestartPuzzleModal(
                onCancel: { showGameRestartConfirmation = false },
                onRestart: {
                    showGameRestartConfirmation = false
                    restartCurrentPuzzle(game: game)
                }
            )
        }
    }

    @ViewBuilder
    private var detailModalOverlay: some View {
        if let slot = savePendingArchive {
            SudylkoDetailModalOverlay(onDismiss: { savePendingArchive = nil }) {
                ArchiveSaveModal(
                    gameTitle: slot.gameTitle,
                    onCancel: { savePendingArchive = nil },
                    onArchive: {
                        savePendingArchive = nil
                        archiveSave(id: slot.id)
                    }
                )
            }
        } else if let kind = pendingProgressReset {
            SudylkoDetailModalOverlay(onDismiss: { pendingProgressReset = nil }) {
                ProgressResetModal(
                    kind: kind,
                    onCancel: { pendingProgressReset = nil },
                    onConfirm: {
                        ProgressResetKind.perform(kind)
                        pendingProgressReset = nil
                    }
                )
            }
        } else if showGameArchiveConfirmation {
            SudylkoDetailModalOverlay(onDismiss: { showGameArchiveConfirmation = false }) {
                gameArchiveModal
            }
        } else if showGameRestartConfirmation {
            SudylkoDetailModalOverlay(onDismiss: { showGameRestartConfirmation = false }) {
                gameRestartModal
            }
        } else if showSeedSheet {
            SudylkoDetailModalOverlay(onDismiss: { showSeedSheet = false }) {
                seedSheet
            }
        } else if showKeyboardShortcuts {
            SudylkoDetailModalOverlay(onDismiss: { showKeyboardShortcuts = false }) {
                keyboardShortcutsSheet
            }
        } else if showsDeleteAllSavesModal {
            SudylkoDetailModalOverlay(onDismiss: { showDeleteAllSavesConfirmation = false }) {
                deleteAllSavesModal
            }
        }
    }

    private var showsDeleteAllSavesModal: Bool {
        #if DEBUG
        showDeleteAllSavesConfirmation
        #else
        false
        #endif
    }

    private var hasDetailModalPresented: Bool {
        savePendingArchive != nil
            || pendingProgressReset != nil
            || showGameArchiveConfirmation
            || showGameRestartConfirmation
            || showSeedSheet
            || showKeyboardShortcuts
            || showsDeleteAllSavesModal
    }

    @discardableResult
    private func dismissDetailModalsIfNeeded() -> Bool {
        guard hasDetailModalPresented else { return false }
        dismissDetailModals()
        return true
    }

    private func dismissDetailModals() {
        savePendingArchive = nil
        pendingProgressReset = nil
        showGameArchiveConfirmation = false
        showGameRestartConfirmation = false
        showSeedSheet = false
        showKeyboardShortcuts = false
        #if DEBUG
        showDeleteAllSavesConfirmation = false
        #endif
    }

    /// Escape while playing: dismiss modal or settings before leaving the puzzle.
    private func handleGameEscape() -> Bool {
        if dismissDetailModalsIfNeeded() { return true }
        if showSettings {
            showSettings = false
            return true
        }
        return false
    }

    #if DEBUG
    private var deleteAllSavesModal: some View {
        DeleteAllSavesModal(
            onCancel: { showDeleteAllSavesConfirmation = false },
            onDelete: {
                showDeleteAllSavesConfirmation = false
                SaveLoadWork.deleteAll()
            }
        )
    }
    #endif

    private func handleSavesDidChange(_ notification: Notification) {
        if notification.object as? SavesChangeReason == .deleteAll {
            lastFocusedSaveIDString = ""
            if isInGame {
                goHome()
            }
        }
        refreshSaveSlotsInBackground()
    }

    private func handleSystemThemeDidChange() {
        guard appearanceMode == .system else { return }
        refreshAppearanceFromSettings()
    }

    /// Timer, stats, and sidebar when `outcome` becomes `.won` or `.lost`. Board already saved via `puzzleRevision`.
    private func handleOutcomeChange(from old: PuzzleOutcome?, to new: PuzzleOutcome?) {
        guard let new, old != new else { return }
        switch new {
        case .playing:
            break
        case .won:
            puzzleTimer.finish()
            refreshSaveSlotsInBackground()
            guard shouldRecordCompletionStats() else { return }
            evaluateAchievementsAfterCompletion()
        case .lost:
            puzzleTimer.finish()
            if let game {
                AchievementStore.recordImpossibleLoss(difficulty: game.difficulty)
            }
            refreshSaveSlotsInBackground()
        }
    }

    /// True only on the first stats/achievement pass for this save's win (not restore/revisit).
    private func shouldRecordCompletionStats() -> Bool {
        !(activeSaveMetadata?.statsCompletionRecorded ?? false)
    }

    private func applyGameplaySettingsToActiveGame() {
        game?.revealMistakesImmediately = revealMistakesImmediately
        game?.impossibleMode = impossibleMode
        game?.refreshMistakes()
    }

    private var sidebar: some View {
        AppSidebar(
            activeSaveID: $activeSaveID,
            liveTimerSaveID: liveTimerSaveID,
            isInGame: isInGame,
            saveSlots: saveSlots,
            liveTimer: puzzleTimer,
            onNewGame: handleNewGameFromSidebar,
            onSelectSave: selectSaveFromSidebar,
            onArchiveSave: archiveSave,
            savePendingArchive: $savePendingArchive,
            pendingProgressReset: $pendingProgressReset
        )
    }

    private func selectSaveFromSidebar(id: UUID) {
        dismissDetailModals()
        selectSave(id: id)
        #if os(iOS)
        showSavesSheet = false
        #endif
    }

    private func handleNewGameFromSidebar() {
        dismissDetailModals()
        #if os(iOS)
        showSavesSheet = false
        #endif
        handleNewGameButton()
    }

    private var detailColumn: some View {
        ZStack {
            homeView
                .opacity(isInGame ? 0 : 1)
                .allowsHitTesting(!isInGame)
            if let game, let saveID = activeSaveID {
                activeGameView(game: game, saveID: saveID)
                    .opacity(isInGame ? 1 : 0)
                    .allowsHitTesting(isInGame)
            }
        }
        .animation(detailNavigationAnimation, value: isInGame)
        .overlay {
            GameOverlayHost(
                phase: gameOverlayPhase,
                achievement: activeCelebration,
                formattedElapsed: puzzleTimer.formattedElapsed,
                buttonTint: appAccent.prominentTint,
                colorScheme: resolvedColorScheme,
                onDismissAchievement: {
                    activeCelebration = nil
                    presentNextCelebration()
                },
                onDismissPuzzleEnd: dismissPuzzleEndBanner,
                onEndGameAction: {
                    dismissPuzzleEndBanner()
                    goHome()
                }
            )
        }
        .overlay {
            detailModalOverlay
        }
        .toolbar { detailToolbar }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hiddenWindowToolbar()
    }

    private var detailNavigationAnimation: Animation {
        .easeInOut(duration: 0.25)
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if isInGame, let game, activeSaveID != nil {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.left", action: goHome)
                    .font(.body)
                    .help("Back to home and save this game")
            }
            ToolbarItem(placement: .principal) {
                GameTimerBar(
                    timer: puzzleTimer,
                    isPuzzleEnded: game.isPuzzleEnded,
                    endedLabel: endedLabel(for: game.outcome),
                    endedLabelColor: endedLabelColor(for: game.outcome)
                )
                .fixedSize()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Archive", systemImage: "archivebox", role: .destructive) {
                    if game.outcome.requiresArchiveConfirmation {
                        showGameArchiveConfirmation = true
                    } else if let saveID = activeSaveID {
                        archiveSave(id: saveID)
                    }
                }
                .font(.body)
                .help("Archive this saved game")
                Button("Restart", systemImage: "arrow.counterclockwise") {
                    if game.hasPlayerEntries {
                        showGameRestartConfirmation = true
                    } else {
                        restartCurrentPuzzle(game: game)
                    }
                }
                .font(.body)
                .help("Restart this puzzle from the beginning")
                settingsToolbarButton
            }
        } else {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button("Saves", systemImage: "sidebar.left") {
                    toggleSidebar()
                }
            }
            #else
            ToolbarItem {
                Spacer()
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                settingsToolbarButton
            }
        }
    }

    @ViewBuilder
    private func activeGameView(game: GameViewModel, saveID: UUID) -> some View {
        GamePlayView(
            game: game,
            timer: puzzleTimer,
            onGoHome: goHome,
            onEscape: handleGameEscape,
            showSettings: $showSettings
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeView: some View {
        HomeView(
            onEasy: { startNewGame(difficulty: .easy) },
            onMedium: { startNewGame(difficulty: .medium) },
            onHard: { startNewGame(difficulty: .hard) },
            onFromSeed: {
                seedSheetDifficulty = lastFocusedDifficulty
                if let prefill = PuzzleSeed.prefillFromClipboard(defaultDifficulty: lastFocusedDifficulty) {
                    seedInput = prefill.text
                    seedSheetDifficulty = prefill.difficulty
                } else {
                    seedInput = ""
                }
                showSeedSheet = true
            },
        )
        .navigationTitle("")
        .hiddenWindowToolbar()
        #if os(macOS)
        .background {
            if !isInGame {
                EscapeKeyboardHost(onEscape: handleHomeEscape)
            }
        }
        #endif
    }

    private func toggleSidebar() {
        #if os(iOS)
        showSavesSheet.toggle()
        #else
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
        #endif
    }

    private func toggleSettings() {
        showSettings.toggle()
    }

    private func handleHomeEscape() -> Bool {
        if dismissDetailModalsIfNeeded() { return true }
        if showSettings {
            showSettings = false
            return true
        }
        return false
    }

    private func handleNewGameButton() {
        if isInGame {
            goHome()
        } else {
            startNewGame(difficulty: lastFocusedDifficulty)
        }
    }

    private func assignGame(_ newGame: GameViewModel?) {
        game = newGame
        appCommands.sync(with: newGame)
        isPuzzleEndBannerVisible = newGame?.outcome.isEnded ?? false
    }

    private func goHome() {
        pauseAndPersistOutgoingGame()
        withAnimation(detailNavigationAnimation) {
            clearActiveGameState()
            #if os(iOS)
            showSavesSheet = false
            #endif
        }
    }

    private func clearActiveGameState() {
        assignGame(nil)
        activeSaveID = nil
        activeSaveMetadata = nil
        puzzleTimer.reset()
        updateDockIcon()
    }

    private var settingsToolbarButton: some View {
        Button("Settings", systemImage: "gearshape") {
            showSettings = true
        }
        .font(.body)
        .help("Open appearance and puzzle settings")
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
            SettingsPopoverView()
                .environment(\.colorScheme, resolvedColorScheme)
                .preferredColorScheme(resolvedColorScheme)
        }
    }

    private func startNewGame(difficulty: GameDifficulty) {
        pauseAndPersistOutgoingGame()
        lastDifficultyRaw = difficulty.rawValue
        seedSheetDifficulty = difficulty

        if let prepared = randomPuzzlePrep.consume(difficulty: difficulty) {
            beginNewGame(
                puzzleSeed: prepared.puzzleSeed,
                startedFromCustomSeed: false,
                preparedTemplate: prepared.template
            )
        } else {
            beginNewGame(
                puzzleSeed: PuzzleSeed.random(difficulty: difficulty),
                startedFromCustomSeed: false
            )
        }
    }

    private func beginNewGame(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool,
        preparedTemplate: GeneratedPuzzle? = nil
    ) {
        saveLoadTask?.cancel()
        saveLoadTask = Task {
            await beginNewGameAsync(
                puzzleSeed: puzzleSeed,
                startedFromCustomSeed: startedFromCustomSeed,
                preparedTemplate: preparedTemplate
            )
        }
    }

    @MainActor
    private func beginNewGameAsync(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool,
        preparedTemplate: GeneratedPuzzle? = nil
    ) async {
        let needsGeneration = preparedTemplate == nil
        if needsGeneration {
            loadingMessage = "Generating puzzle…"
        }
        defer {
            if needsGeneration {
                loadingMessage = nil
            }
        }

        let payload: SaveLoadWork.NewGamePayload
        if let preparedTemplate {
            payload = SaveLoadWork.NewGamePayload(
                template: preparedTemplate,
                puzzleSeed: puzzleSeed,
                startedFromCustomSeed: startedFromCustomSeed
            )
        } else {
            payload = await Task.detached(priority: .userInitiated) {
                SaveLoadWork.newGamePayload(
                    puzzleSeed: puzzleSeed,
                    startedFromCustomSeed: startedFromCustomSeed
                )
            }.value
        }

        guard !Task.isCancelled else { return }

        if let started = AchievementStore.recordGameStarted(
            difficulty: puzzleSeed.difficulty,
            fromCustomSeed: startedFromCustomSeed
        ) {
            enqueueCelebrations([started])
        }

        let saveID = UUID()
        let newGame = GameViewModel(
            puzzleSeed: payload.puzzleSeed,
            startedFromCustomSeed: payload.startedFromCustomSeed,
            template: payload.template
        )

        let metadata = SavePersistMetadata(
            createdAt: Date(),
            isArchived: false,
            statsCompletionRecorded: false
        )
        let state = SavedGameState.from(
            id: saveID,
            game: newGame,
            timer: puzzleTimer,
            metadata: metadata
        )
        activeSaveMetadata = metadata
        SaveLoadWork.enqueueSave(state)
        refreshSaveSlotsInBackground()

        lastFocusedSaveIDString = saveID.uuidString
        withAnimation(detailNavigationAnimation) {
            assignGame(newGame)
            activeSaveID = saveID
        }
        applyGameplaySettingsToActiveGame()
        puzzleTimer.start()
        updateDockIcon()
        randomPuzzlePrep.schedulePrepForAllDifficulties()
    }

    /// Sidebar row selection — routes through `activeSaveID` so loading uses one code path.
    private func selectSave(id: UUID) {
        if activeSaveID == id {
            if game != nil {
                resumeLoadedGameIfNeeded()
            } else {
                switchToSave(id: id)
            }
            return
        }
        activeSaveID = id
    }

    private func switchToSave(id: UUID) {
        saveLoadTask?.cancel()
        saveLoadTask = Task {
            await performSaveSwitch(to: id)
        }
    }

    @MainActor
    private func performSaveSwitch(to id: UUID) async {
        if game != nil, lastFocusedSaveIDString == id.uuidString {
            resumeLoadedGameIfNeeded()
            return
        }

        loadingMessage = "Loading game…"
        defer { loadingMessage = nil }

        let outgoing = captureOutgoingSave(excluding: id)

        async let incoming = Task.detached(priority: .userInitiated) {
            SaveLoadWork.restorePayload(saveID: id)
        }
        if let outgoing {
            SaveLoadWork.enqueueSave(outgoing)
        }

        let payload = await incoming.value

        guard !Task.isCancelled else { return }

        guard let payload else {
            if let previous = UUID(uuidString: lastFocusedSaveIDString) {
                activeSaveID = previous
            } else {
                activeSaveID = nil
            }
            return
        }

        var state = payload.state
        lastDifficultyRaw = state.difficulty.rawValue

        if state.outcome == .won, !state.statsCompletionRecorded {
            let unlocked = AchievementStore.recordCompletion(
                AchievementCompletionContext(save: state),
                save: state
            )
            enqueueCelebrations(unlocked)
            state.statsCompletionRecorded = true
            SaveLoadWork.enqueueSave(state)
        }

        let restored = GameViewModel.restored(from: state, template: payload.template)
        puzzleTimer.restore(from: state)
        activeSaveMetadata = SavePersistMetadata(state: state)
        lastFocusedSaveIDString = id.uuidString
        withAnimation(detailNavigationAnimation) {
            assignGame(restored)
            activeSaveID = id
        }
        applyGameplaySettingsToActiveGame()
        resumeLoadedGameIfNeeded()
        updateDockIcon()

        refreshSaveSlotsInBackground()
    }

    private func resumeLoadedGameIfNeeded() {
        guard let game, !game.isPuzzleEnded else { return }
        guard puzzleTimer.isRunning else { return }
        if puzzleTimer.isPaused {
            puzzleTimer.resume()
        }
    }

    /// Snapshots the in-memory game for disk without blocking on unrelated saves.
    private func captureOutgoingSave(excluding excludedID: UUID? = nil) -> SavedGameState? {
        guard let outgoingID = activeSaveID,
              outgoingID != excludedID,
              let game,
              isInGame else { return nil }
        if puzzleTimer.isRunning, !puzzleTimer.isPaused, !game.isPuzzleEnded {
            puzzleTimer.pause()
        }
        guard let metadata = activeSaveMetadata else { return nil }
        return SavedGameState.from(
            id: outgoingID,
            game: game,
            timer: puzzleTimer,
            metadata: metadata
        )
    }

    private func pauseAndPersistOutgoingGame(excluding excludedID: UUID? = nil) {
        guard let state = captureOutgoingSave(excluding: excludedID) else { return }
        SaveLoadWork.enqueueSave(state)
        refreshSaveSlotsInBackground()
    }

    private func persistOutgoingGameIfNeeded(excluding excludedID: UUID? = nil) {
        guard let state = captureOutgoingSave(excluding: excludedID) else { return }
        SaveLoadWork.enqueueSave(state)
    }

    private func performInitialSetup() {
        seedSheetDifficulty = lastFocusedDifficulty
        #if os(macOS)
        columnVisibility = .all
        #endif
        syncSystemColorSchemeFromPlatform()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        refreshSaveSlotsInBackground()
        randomPuzzlePrep.schedulePrepForAllDifficulties()
        Task {
            if let id = UUID(uuidString: lastFocusedSaveIDString),
               await Task.detached(priority: .utility) { SaveLoadWork.load(id: id) }.value == nil {
                lastFocusedSaveIDString = ""
            }
            await restoreLastSessionIfNeeded()
        }
        #if os(macOS)
        isAppActive = NSApp.isActive
        #else
        isAppActive = scenePhase == .active
        #endif
        updateDockIcon()
    }

    private func handleActiveSaveIDChange(from oldID: UUID?, to newID: UUID?) {
        if newID == nil {
            if isInGame, let oldID {
                activeSaveID = oldID
            }
            return
        }
        guard let newID else { return }
        if newID == oldID, game != nil, lastFocusedSaveIDString == newID.uuidString {
            return
        }
        switchToSave(id: newID)
    }

    private var shouldHoldAutoPause: Bool {
        !isAppActive || showSettings || isWindowMiniaturized
    }

    private func handleAppActiveChange(_ active: Bool) {
        if !active {
            persistGameplaySession()
        }
        updateAutoPauseForInterrupts()
        updateDockIcon()
    }

    private func updateAutoPauseForInterrupts() {
        if shouldHoldAutoPause {
            pauseForAutoInterruptIfNeeded()
        } else {
            resumeAfterAutoPauseIfNeeded()
        }
    }

    private func pauseForAutoInterruptIfNeeded() {
        guard isInGame, let game, !game.isPuzzleEnded else { return }
        guard puzzleTimer.isRunning, !puzzleTimer.isPaused else { return }
        puzzleTimer.pause()
        autoPausedForInactive = true
    }

    private func resumeAfterAutoPauseIfNeeded() {
        guard autoPausedForInactive else { return }
        guard puzzleTimer.isRunning, puzzleTimer.isPaused else {
            autoPausedForInactive = false
            return
        }
        puzzleTimer.resume()
        autoPausedForInactive = false
    }

    private func evaluateAchievementsAfterCompletion() {
        guard let game, let snapshot = captureOutgoingSave() else { return }
        let context = AchievementCompletionContext(
            difficulty: game.difficulty,
            elapsedSeconds: puzzleTimer.elapsed,
            startedFromCustomSeed: game.startedFromCustomSeed,
            mistakesInPuzzle: game.mistakesThisPuzzle,
            usedNotes: game.usedNotesThisPuzzle
        )
        enqueueCelebrations(AchievementStore.recordCompletion(context, save: snapshot))
        markStatsCompletionRecordedInSession()
    }

    private func markStatsCompletionRecordedInSession() {
        guard var metadata = activeSaveMetadata, !metadata.statsCompletionRecorded else { return }
        metadata.statsCompletionRecorded = true
        activeSaveMetadata = metadata
    }

    private func restartCurrentPuzzle(game: GameViewModel) {
        if let started = AchievementStore.recordGameStarted(
            difficulty: game.difficulty,
            fromCustomSeed: game.startedFromCustomSeed
        ) {
            enqueueCelebrations([started])
        }
        game.replayCurrentPuzzle()
        puzzleTimer.start()
        if var metadata = activeSaveMetadata {
            metadata.statsCompletionRecorded = false
            activeSaveMetadata = metadata
        }
        if var snapshot = captureOutgoingSave() {
            snapshot.statsCompletionRecorded = false
            SaveLoadWork.enqueueSave(snapshot)
        }
        persistCurrentGame()
    }

    private func enqueueCelebrations(_ ids: [AchievementID]) {
        guard !ids.isEmpty else { return }
        celebrationQueue.append(contentsOf: ids)
        presentNextCelebration()
    }

    private func presentNextCelebration() {
        guard activeCelebration == nil, !celebrationQueue.isEmpty else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            activeCelebration = celebrationQueue.removeFirst()
        }
    }

    private func refreshAppearanceFromSettings() {
        syncSystemColorSchemeFromPlatform()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        updateDockIcon()
        #if os(macOS)
        if appearanceMode == .system {
            Task { @MainActor in
                syncSystemColorSchemeFromPlatform()
                appAccent.systemColorScheme = systemColorScheme
                appAccent.refresh()
                updateDockIcon()
            }
        }
        #endif
    }

    private func syncSystemColorSchemeFromPlatform() {
        systemColorScheme = AppearanceMode.systemColorScheme()
    }

    /// Avoid pausing/resuming the timer during an in-flight SwiftUI layout pass.
    private func scheduleAutoPauseInterruptUpdate() {
        Task { @MainActor in
            updateAutoPauseForInterrupts()
        }
    }

    private func updateDockIcon() {
        let inGame = isInGame
        let showPaused = inGame && puzzleTimer.isPaused
        let timerText: String? = inGame && !showPaused && puzzleTimer.isRunning
            ? puzzleTimer.formattedElapsed
            : nil
        DockIconRenderer.updateDockIcon(
            accent: appAccent.accent,
            colorScheme: resolvedColorScheme,
            inGame: inGame,
            showPaused: showPaused,
            timerText: timerText
        )
    }

    @MainActor
    private func restoreLastSessionIfNeeded() async {
        guard !isInGame else { return }
        guard let id = UUID(uuidString: lastFocusedSaveIDString) else { return }
        let state = await Task.detached(priority: .utility) {
            SaveLoadWork.load(id: id)
        }.value
        guard let state, state.outcome == .playing else { return }
        await performSaveSwitch(to: id)
    }

    /// Board + outcome only (triggered by `puzzleRevision`).
    private func persistPuzzleProgress() {
        persistOutgoingGameIfNeeded()
    }

    /// Session chrome and timer (pencil mode, selection, pause, background, switch save).
    private func persistSessionState() {
        persistOutgoingGameIfNeeded()
    }

    /// Timer pause/background also refreshes sidebar elapsed times.
    private func persistGameplaySession() {
        persistSessionState()
        refreshSaveSlotsInBackground()
    }

    /// Full save file plus sidebar reload (new game, switch save, archive, restart).
    private func persistCurrentGame() {
        persistGameplaySession()
    }

    private func endedLabel(for outcome: PuzzleOutcome) -> String? {
        switch outcome {
        case .playing: nil
        case .won: "Done"
        case .lost: "Lost"
        }
    }

    private func endedLabelColor(for outcome: PuzzleOutcome) -> Color {
        switch outcome {
        case .playing: .primary
        case .won: .green
        case .lost: .red
        }
    }

    private func refreshSaveSlotsInBackground() {
        Task.detached(priority: .utility) {
            let slots = SaveLoadWork.summaries()
            await MainActor.run {
                saveSlots = slots
            }
        }
    }

    private func archiveSave(id: UUID) {
        let isCurrentGame = activeSaveID == id && isInGame

        Task.detached(priority: .utility) {
            if let state = SaveLoadWork.load(id: id),
               !state.isArchived,
               state.outcome == .playing,
               let abandoned = AchievementStore.recordAbandonedSave(difficulty: state.difficulty) {
                await MainActor.run {
                    enqueueCelebrations([abandoned])
                }
            }
            SaveLoadWork.archive(id: id)
            await MainActor.run {
                if lastFocusedSaveIDString == id.uuidString {
                    lastFocusedSaveIDString = ""
                }
                refreshSaveSlotsInBackground()
                guard isCurrentGame else { return }
                withAnimation(detailNavigationAnimation) {
                    clearActiveGameState()
                }
            }
        }
    }

}
