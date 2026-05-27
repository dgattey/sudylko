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
    @AppStorage("digitFontStyle") private var fontStyleRaw = DigitFontStyle.rounded.rawValue
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
    #if os(iOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    #else
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif
    @State private var homeProgressInspectorPresented = false
    @State private var homeInspectorSection: HomeProgressSection?
    @StateObject private var puzzleTimer = PuzzleTimer()
    /// Tracks macOS system appearance when `appearanceMode == .system` (updated via distributed notification).
    @State private var systemColorScheme = AppearanceMode.systemColorScheme()
    @State private var saveSlots: [SaveSlotSummary] = []
    /// Bumped whenever saves reload so the sidebar list re-renders after menu-driven seeds.
    @State private var saveSlotsRevision = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var celebrationQueue: [AchievementID] = []
    @State private var activeCelebration: AchievementID?
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var digitFont: DigitFontStyle {
        DigitFontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    private var resolvedColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme(system: systemColorScheme)
    }

    private var isInGame: Bool {
        game != nil && activeSaveID != nil
    }

    #if os(macOS)
    private var showsSidebar: Bool {
        columnVisibility != .detailOnly
    }

    private var macWindowMinimumSize: CGSize {
        WindowLayoutMetrics.minimumSize(
            showsSidebar: showsSidebar,
            showsHomeInspector: !isInGame && homeProgressInspectorPresented
        )
    }
    #endif

    private var lastFocusedDifficulty: GameDifficulty {
        if let id = UUID(uuidString: lastFocusedSaveIDString),
           let state = GameSaveStore.load(id: id) {
            return state.difficulty
        }
        return GameDifficulty(rawValue: lastDifficultyRaw) ?? .medium
    }

    var body: some View {
        appChrome
    }

    private var keyboardShortcutsSheet: some View {
        KeyboardShortcutsView()
            .environment(\.colorScheme, resolvedColorScheme)
    }

    /// Wraps all window UI including sheets so accent `tint` is not scoped only to `rootSplitView`.
    private var appChrome: some View {
        appChromeWithLifecycle
    }

    private var appChromeWithSheets: some View {
        rootSplitView
            .overlay { gameOverlays }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: game?.isPuzzleEnded == true)
            .sheet(isPresented: $showSeedSheet) { seedSheet }
            .sheet(isPresented: $showKeyboardShortcuts) { keyboardShortcutsSheet }
    }

    private var appChromeWithLifecycle: some View {
        appChromeWithSheets
            .onAppear {
                AppCommandState.live = appCommands
                appAccent.refresh()
                performInitialSetup()
            }
            .onChange(of: game?.isComplete) { old, new in
                handleGameCompletionChange(old, isComplete: new)
            }
            .onChange(of: game?.isLost, handleGameLossChange)
            .onChange(of: game?.saveRevision) { _, _ in schedulePersist() }
            .onChange(of: appAccent.accent) { _, _ in updateDockIcon() }
            .onChange(of: revealMistakesImmediately) { _, _ in
                applyGameplaySettingsToActiveGame()
            }
            .onChange(of: impossibleMode) { _, _ in
                applyGameplaySettingsToActiveGame()
            }
    }

    private var rootSplitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                #if os(macOS)
                .navigationSplitViewColumnWidth(SidebarMetrics.width)
                #endif
        } detail: {
            detailColumn
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #else
        .navigationSplitViewStyle(.automatic)
        #endif
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
        .environment(\.digitFontStyle, digitFont)
        .environment(\.isAppActive, isAppActive)
        .environment(\.isWindowFullscreen, isWindowFullscreen)
        .preferredColorScheme(appearanceMode.preferredColorScheme(system: systemColorScheme))
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
        .onChange(of: showSettings) { _, _ in updateAutoPauseForInterrupts() }
        .onChange(of: isWindowMiniaturized) { _, _ in updateAutoPauseForInterrupts() }
        .onChange(of: activeSaveID) { oldID, newID in
            handleActiveSaveIDChange(from: oldID, to: newID)
            updateDockIcon()
        }
        .onChange(of: isInGame) { _, inGame in
            if inGame {
                homeProgressInspectorPresented = false
                homeInspectorSection = nil
                #if os(iOS)
                columnVisibility = .detailOnly
                #endif
            }
        }
        .onChange(of: puzzleTimer.isPaused) { _, _ in
            persistCurrentGame()
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
        .onChange(of: game?.saveRevision) { _, _ in appCommands.sync(with: game) }
    }

    @ViewBuilder
    private var gameOverlays: some View {
        if let celebration = activeCelebration {
            AchievementCelebrationView(achievement: celebration) {
                activeCelebration = nil
                presentNextCelebration()
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .zIndex(2)
        }

        if game?.isComplete == true {
            completionBanner
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
        }

        if game?.isLost == true {
            lossBanner
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
        }
    }

    private var seedSheet: some View {
        CustomPuzzleSheet(
            seedInput: $seedInput,
            difficulty: $seedSheetDifficulty,
            canStart: canStartFromSeedInput,
            onCancel: { showSeedSheet = false },
            onStart: {
                let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if let seed = PuzzleSeed.parse(trimmed, difficulty: seedSheetDifficulty) {
                    startFromSeed(seed)
                    showSeedSheet = false
                }
            }
        )
    }

    private func handleSavesDidChange(_ notification: Notification) {
        if notification.object as? SavesChangeReason == .deleteAll {
            lastFocusedSaveIDString = ""
            if isInGame {
                goHome()
            }
        }
        refreshSaveSlots()
    }

    private func handleSystemThemeDidChange() {
        systemColorScheme = AppearanceMode.systemColorScheme()
        appAccent.systemColorScheme = systemColorScheme
        if appearanceMode == .system {
            refreshAppearanceFromSettings()
        }
    }

    private func handleGameCompletionChange(_ old: Bool?, isComplete new: Bool?) {
        guard new == true, old != true else { return }
        puzzleTimer.finish()
        persistCurrentGame()
        guard shouldRecordCompletionStats() else { return }
        evaluateAchievementsAfterCompletion()
    }

    /// True only on the first stats/achievement pass for this save's win (not restore/revisit).
    private func shouldRecordCompletionStats() -> Bool {
        guard let saveID = activeSaveID,
              let save = GameSaveStore.load(id: saveID) else { return true }
        return !save.statsCompletionRecorded
    }

    private func handleGameLossChange(_: Bool?, isLost: Bool?) {
        guard isLost == true, let game else { return }
        puzzleTimer.finish()
        AchievementStore.recordImpossibleLoss(difficulty: game.difficulty)
        persistCurrentGame()
    }

    private func applyGameplaySettingsToActiveGame() {
        game?.revealMistakesImmediately = revealMistakesImmediately
        game?.impossibleMode = impossibleMode
        game?.refreshMistakes()
    }

    private var sidebar: some View {
        AppSidebar(
            activeSaveID: $activeSaveID,
            isInGame: isInGame,
            saveSlots: saveSlots,
            saveSlotsRevision: saveSlotsRevision,
            liveTimer: puzzleTimer,
            onNewGame: handleNewGameButton,
            onSelectSave: selectSave,
            onArchiveSave: archiveSave
        )
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
                    .help("Back to home and save this game")
            }
            ToolbarItem(placement: .principal) {
                GameTimerBar(
                    timer: puzzleTimer,
                    isPuzzleEnded: game.isPuzzleEnded,
                    endedLabel: game.isComplete ? "Done" : (game.isLost ? "Lost" : nil),
                    endedLabelColor: game.isComplete ? .green : .red
                )
                .fixedSize()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Archive", systemImage: "archivebox", role: .destructive) {
                    showGameArchiveConfirmation = true
                }
                .help("Archive this saved game")
                Button("Restart", systemImage: "arrow.counterclockwise") {
                    if game.hasPlayerEntries {
                        showGameRestartConfirmation = true
                    } else {
                        restartCurrentPuzzle(game: game)
                    }
                }
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
            onRestart: {
                restartCurrentPuzzle(game: game)
            },
            onArchive: {
                archiveSave(id: saveID)
            },
            onGoHome: goHome,
            showSettings: $showSettings,
            showArchiveConfirmation: $showGameArchiveConfirmation,
            showRestartConfirmation: $showGameRestartConfirmation
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeView: some View {
        HomeView(
            onEasy: { startNewGame(difficulty: .easy) },
            onMedium: { startNewGame(difficulty: .medium) },
            onHard: { startNewGame(difficulty: .hard) },
            onFromSeed: {
                seedInput = ""
                seedSheetDifficulty = lastFocusedDifficulty
                showSeedSheet = true
            },
            inspectorPresented: $homeProgressInspectorPresented,
            inspectorSection: $homeInspectorSection
        )
        .modifier(HomeProgressPresentationModifier(
            isPresented: $homeProgressInspectorPresented,
            section: homeInspectorSection
        ))
        .navigationTitle("")
        .hiddenWindowToolbar()
        #if os(macOS)
        .background {
            EscapeKeyboardHost(onEscape: dismissSettingsIfNeeded)
        }
        #endif
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .all ? .detailOnly : .all
        }
    }

    private func toggleSettings() {
        showSettings.toggle()
    }

    private func dismissSettingsIfNeeded() -> Bool {
        guard showSettings else { return false }
        showSettings = false
        return true
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
    }

    private func goHome() {
        pauseAndPersistOutgoingGame()
        withAnimation(detailNavigationAnimation) {
            clearActiveGameState()
            #if os(iOS)
            columnVisibility = .detailOnly
            #endif
        }
    }

    private func clearActiveGameState() {
        assignGame(nil)
        activeSaveID = nil
        puzzleTimer.reset()
        updateDockIcon()
    }

    private var settingsToolbarButton: some View {
        Button("Settings", systemImage: "gearshape") {
            showSettings = true
        }
        .help("Open appearance and puzzle settings")
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
            SettingsPopoverView()
        }
    }

    private func startNewGame(difficulty: GameDifficulty) {
        pauseAndPersistOutgoingGame()
        lastDifficultyRaw = difficulty.rawValue
        seedSheetDifficulty = difficulty
        beginNewGame(
            puzzleSeed: PuzzleSeed.random(difficulty: difficulty),
            startedFromCustomSeed: false
        )
    }

    private func startFromSeed(_ puzzleSeed: PuzzleSeed) {
        pauseAndPersistOutgoingGame()
        lastDifficultyRaw = puzzleSeed.difficulty.rawValue
        beginNewGame(puzzleSeed: puzzleSeed, startedFromCustomSeed: true)
    }

    private func beginNewGame(puzzleSeed: PuzzleSeed, startedFromCustomSeed: Bool) {
        if let started = AchievementStore.recordGameStarted(
            difficulty: puzzleSeed.difficulty,
            fromCustomSeed: startedFromCustomSeed
        ) {
            enqueueCelebrations([started])
        }

        let saveID = UUID()
        let newGame = makeGame(puzzleSeed: puzzleSeed, startedFromCustomSeed: startedFromCustomSeed)

        let state = SavedGameState.from(
            id: saveID,
            game: newGame,
            timer: puzzleTimer,
            createdAt: Date()
        )
        GameSaveStore.save(state)
        refreshSaveSlots()

        lastFocusedSaveIDString = saveID.uuidString
        withAnimation(detailNavigationAnimation) {
            assignGame(newGame)
            activeSaveID = saveID
        }
        puzzleTimer.start()
        updateDockIcon()
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
        if game != nil, activeSaveID == id {
            resumeLoadedGameIfNeeded()
            return
        }

        pauseAndPersistOutgoingGame(excluding: id)

        guard var state = GameSaveStore.load(id: id) else {
            if let previous = UUID(uuidString: lastFocusedSaveIDString) {
                activeSaveID = previous
            } else {
                activeSaveID = nil
            }
            return
        }

        lastFocusedSaveIDString = id.uuidString
        lastDifficultyRaw = state.difficulty.rawValue

        if state.isComplete, !state.statsCompletionRecorded {
            state.statsCompletionRecorded = true
            GameSaveStore.save(state)
        }

        let restored = GameViewModel.restored(from: state)
        puzzleTimer.restore(from: state)
        withAnimation(detailNavigationAnimation) {
            assignGame(restored)
            activeSaveID = id
        }
        applyGameplaySettingsToActiveGame()
        resumeLoadedGameIfNeeded()
        updateDockIcon()
    }

    private func resumeLoadedGameIfNeeded() {
        guard let game, !game.isPuzzleEnded else { return }
        guard puzzleTimer.isRunning else { return }
        if puzzleTimer.isPaused {
            puzzleTimer.resume()
        }
    }

    private func pauseAndPersistOutgoingGame(excluding excludedID: UUID? = nil) {
        guard let outgoingID = activeSaveID,
              outgoingID != excludedID,
              let game,
              isInGame else { return }
        if puzzleTimer.isRunning, !puzzleTimer.isPaused, !game.isPuzzleEnded {
            puzzleTimer.pause()
        }
        guard let createdAt = GameSaveStore.load(id: outgoingID)?.createdAt else { return }
        let state = SavedGameState.from(
            id: outgoingID,
            game: game,
            timer: puzzleTimer,
            createdAt: createdAt
        )
        GameSaveStore.save(state)
        refreshSaveSlots()
    }

    private func persistOutgoingGameIfNeeded(excluding excludedID: UUID? = nil) {
        guard let outgoingID = activeSaveID,
              outgoingID != excludedID,
              let game,
              isInGame,
              let createdAt = GameSaveStore.load(id: outgoingID)?.createdAt else { return }
        let state = SavedGameState.from(
            id: outgoingID,
            game: game,
            timer: puzzleTimer,
            createdAt: createdAt
        )
        GameSaveStore.save(state)
    }

    private func makeGame(puzzleSeed: PuzzleSeed, startedFromCustomSeed: Bool) -> GameViewModel {
        let vm = GameViewModel(puzzleSeed: puzzleSeed, startedFromCustomSeed: startedFromCustomSeed)
        vm.revealMistakesImmediately = revealMistakesImmediately
        vm.impossibleMode = impossibleMode
        return vm
    }

    private func performInitialSetup() {
        seedSheetDifficulty = lastFocusedDifficulty
        #if os(iOS)
        columnVisibility = .detailOnly
        #else
        columnVisibility = .all
        #endif
        if let id = UUID(uuidString: lastFocusedSaveIDString),
           GameSaveStore.load(id: id) == nil {
            lastFocusedSaveIDString = ""
        }
        systemColorScheme = AppearanceMode.systemColorScheme()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        refreshSaveSlots()
        restoreLastSessionIfNeeded()
        #if os(macOS)
        applyWindowAppearance()
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
            persistCurrentGame()
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
        guard let game, let saveID = activeSaveID else { return }
        let context = AchievementCompletionContext(
            difficulty: game.difficulty,
            elapsedSeconds: puzzleTimer.elapsed,
            startedFromCustomSeed: game.startedFromCustomSeed,
            mistakesInPuzzle: game.mistakesThisPuzzle,
            usedNotes: game.usedNotesThisPuzzle
        )
        enqueueCelebrations(AchievementStore.recordCompletion(context, saveID: saveID))
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
        if let id = activeSaveID, var state = GameSaveStore.load(id: id) {
            state.statsCompletionRecorded = false
            GameSaveStore.save(state)
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
        systemColorScheme = AppearanceMode.systemColorScheme()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        applyWindowAppearance()
        updateDockIcon()
    }

    private func applyWindowAppearance() {
        #if os(macOS)
        let appearance = appearanceMode.resolvedNSAppearance() ?? NSApp.effectiveAppearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
        }
        #endif
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

    private func restoreLastSessionIfNeeded() {
        guard !isInGame else { return }
        guard let id = UUID(uuidString: lastFocusedSaveIDString),
              let state = GameSaveStore.load(id: id),
              !state.isComplete, !state.isLost else { return }
        switchToSave(id: id)
    }

    private func schedulePersist() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persistCurrentGame()
            }
        }
    }

    private func persistCurrentGame() {
        persistOutgoingGameIfNeeded()
        refreshSaveSlots()
    }

    private func refreshSaveSlots() {
        saveSlots = GameSaveStore.summaries()
        saveSlotsRevision &+= 1
    }

    private func archiveSave(id: UUID) {
        let isCurrentGame = activeSaveID == id && isInGame

        if let state = GameSaveStore.load(id: id), !state.isArchived, !state.isComplete, !state.isLost,
           let abandoned = AchievementStore.recordAbandonedSave(difficulty: state.difficulty) {
            enqueueCelebrations([abandoned])
        }

        GameSaveStore.archive(id: id)

        if lastFocusedSaveIDString == id.uuidString {
            lastFocusedSaveIDString = ""
        }

        refreshSaveSlots()

        guard isCurrentGame else { return }
        withAnimation(detailNavigationAnimation) {
            clearActiveGameState()
        }
    }

    private var completionBanner: some View {
        PuzzleEndBannerView(
            systemImage: "checkmark.seal.fill",
            iconColor: .green,
            title: "Puzzle complete!",
            subtitle: nil,
            formattedElapsed: puzzleTimer.formattedElapsed,
            buttonTitle: "Play again",
            buttonTint: appAccent.prominentTint,
            onButton: goHome
        )
        .environment(\.colorScheme, resolvedColorScheme)
    }

    private var lossBanner: some View {
        PuzzleEndBannerView(
            systemImage: "xmark.seal.fill",
            iconColor: .red,
            title: "Puzzle lost",
            subtitle: "Impossible mode — one mistake ends the run.",
            formattedElapsed: puzzleTimer.formattedElapsed,
            buttonTitle: "Try again",
            buttonTint: appAccent.prominentTint,
            onButton: goHome
        )
        .environment(\.colorScheme, resolvedColorScheme)
    }

    private var canStartFromSeedInput: Bool {
        let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return PuzzleSeed.parse(trimmed, difficulty: seedSheetDifficulty) != nil
    }
}
