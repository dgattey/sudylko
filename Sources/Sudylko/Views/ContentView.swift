import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Window root: navigation chrome, detail-column modals, settings, and platform lifecycle.
/// Game and save state live in `GameSessionModel`.
struct ContentView: View {
    @EnvironmentObject private var appCommands: AppCommandState
#if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
#endif
    @EnvironmentObject private var appAccent: AppAccentModel
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("puzzleFontStyle") private var fontStyleRaw = PuzzleFontStyle.rounded.rawValue
    @AppStorage("revealMistakesImmediately") private var revealMistakesImmediately = false
    @AppStorage("impossibleMode") private var impossibleMode = false
    @StateObject private var session: GameSessionModel
    @StateObject private var customPuzzlePrep = CustomPuzzlePrepModel()
    @State private var modals = DetailModals()
    @State private var showSettings = false
    @State private var isAppActive = true
    @State private var isWindowMiniaturized = false
    @State private var isWindowFullscreen = false
    /// Tracks macOS system appearance when `appearanceMode == .system` (updated via distributed notification).
    @State private var systemColorScheme = AppearanceMode.systemColorScheme()
    #if os(iOS)
    @State private var keyboardShortcutsPresenter: KeyboardShortcutsPresenter?
    @State private var showSavesSheet = false
    #else
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    init(appAccent: AppAccentModel) {
        _session = StateObject(wrappedValue: GameSessionModel(appAccent: appAccent))
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var puzzleFont: PuzzleFontStyle {
        PuzzleFontStyle(rawValue: fontStyleRaw) ?? .rounded
    }

    private var resolvedColorScheme: ColorScheme {
        appearanceMode.resolvedColorScheme(system: systemColorScheme)
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

    /// `GameViewModel` isn't observed here, so the `session.game?` `onChange` checks run whenever
    /// this view re-renders (session, timer tick, or command-state changes).
    var body: some View {
        chromeWithWindowEvents
            .onAppear {
                appAccent.refresh()
                performInitialSetup()
            }
            .onChange(of: session.game?.outcome) { old, new in
                session.outcomeChanged(from: old, to: new)
            }
            .onChange(of: session.game?.puzzleRevision) { _, _ in
                session.persistActiveGame()
            }
            .onChange(of: session.game?.sessionRevision) { _, _ in
                session.persistActiveGame()
            }
            #if os(macOS)
            .onChange(of: appAccent.accent) { _, _ in
                DockIconRenderer.invalidateCache()
                session.updateDockIcon()
            }
            .onChange(of: appAccent.resolvedColorScheme) { _, _ in
                DockIconRenderer.invalidateCache()
                session.updateDockIcon()
            }
            #endif
            .onChange(of: revealMistakesImmediately) { _, _ in
                session.applyGameplaySettingsToActiveGame()
            }
            .onChange(of: impossibleMode) { _, _ in
                session.applyGameplaySettingsToActiveGame()
            }
    }

    private var chromeWithWindowEvents: some View {
        rootChrome { platformRootCore }
            #if os(iOS)
            .sheet(isPresented: $showSavesSheet) { savesSheet }
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
            .onChange(of: isAppActive) { _, active in
                session.appActivityChanged(isActive: active, holdAutoPause: shouldHoldAutoPause)
            }
            .onChange(of: showSettings) { _, _ in
                scheduleAutoPauseInterruptUpdate()
            }
            .onChange(of: isWindowMiniaturized) { _, _ in
                scheduleAutoPauseInterruptUpdate()
            }
            .onChange(of: session.activeSaveID) { oldID, newID in
                session.handleActiveSaveIDChange(from: oldID, to: newID)
                session.updateDockIcon()
            }
            .onChange(of: session.isInGame) { _, inGame in
                if inGame {
                    #if os(iOS)
                    showSavesSheet = false
                    #endif
                }
            }
            .onChange(of: session.puzzleTimer.isPaused) { _, _ in
                session.persistGameplaySession()
                session.updateDockIcon()
            }
            .onChange(of: session.puzzleTimer.formattedElapsed) { _, _ in
                if session.activeSaveID != nil { session.updateDockIcon() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sudylkoSystemThemeDidChange)) { _ in
                handleSystemThemeDidChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                showSettings.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                toggleSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
                #if os(iOS)
                showSettings = false
                keyboardShortcutsPresenter = showSavesSheet ? .savesSheet : .root
                #else
                modals.showsKeyboardShortcuts = true
                #endif
            }
        #if DEBUG
            .onReceive(NotificationCenter.default.publisher(for: .requestDeleteAllSavesConfirmation)) { _ in
                modals.confirmsDeleteAllSaves = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugAchievementUnlocked)) { notification in
                guard let ids = notification.object as? [AchievementID] else { return }
                session.enqueueCelebrations(ids)
            }
            .onReceive(NotificationCenter.default.publisher(for: .debugTriggerPulse)) { notification in
                guard let kind = notification.object as? DebugPulseKind else { return }
                switch kind {
                case .puzzleComplete:
                    session.game?.debugTriggerPuzzleCompletePulse()
                case .finishedRow:
                    session.game?.debugTriggerFinishedRowPulse()
                case .finishedColumn:
                    session.game?.debugTriggerFinishedColumnPulse()
                case .finishedBox:
                    session.game?.debugTriggerFinishedBoxPulse()
                case .finishedDigit:
                    session.game?.debugTriggerFinishedDigitPulse()
                }
            }
        #endif
            .onReceive(NotificationCenter.default.publisher(for: .savesDidChange), perform: session.handleSavesDidChange)
            .onReceive(NotificationCenter.default.publisher(for: .undo)) { _ in
                session.game?.undo()
                appCommands.sync(with: session.game)
            }
            .onReceive(NotificationCenter.default.publisher(for: .redo)) { _ in
                session.game?.redo()
                appCommands.sync(with: session.game)
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteCell)) { _ in
                session.game?.keyboardClearSelected()
                appCommands.sync(with: session.game)
            }
            .onChange(of: session.game?.canUndo) { _, _ in appCommands.sync(with: session.game) }
            .onChange(of: session.game?.canRedo) { _, _ in appCommands.sync(with: session.game) }
            .onChange(of: session.game?.canDelete) { _, _ in appCommands.sync(with: session.game) }
    }

    @ViewBuilder
    private var platformRootCore: some View {
        #if os(iOS)
        NavigationStack {
            detailColumn
        }
        .sheet(isPresented: keyboardShortcutsBinding(for: .root)) { keyboardShortcutsSheet }
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
        .sheet(isPresented: keyboardShortcutsBinding(for: .savesSheet)) { keyboardShortcutsSheet }
        .onDisappear {
            if keyboardShortcutsPresenter == .savesSheet {
                keyboardShortcutsPresenter = nil
            }
        }
    }

    private enum KeyboardShortcutsPresenter {
        case root
        case savesSheet
    }

    private func keyboardShortcutsBinding(for presenter: KeyboardShortcutsPresenter) -> Binding<Bool> {
        Binding(
            get: { keyboardShortcutsPresenter == presenter },
            set: { isPresented in
                if !isPresented, keyboardShortcutsPresenter == presenter {
                    keyboardShortcutsPresenter = nil
                }
            }
        )
    }

    private var keyboardShortcutsSheet: some View {
        NavigationStack {
            KeyboardShortcutsView()
                .navigationTitle("Keyboard shortcuts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            keyboardShortcutsPresenter = nil
                        }
                    }
                }
        }
        .environment(\.colorScheme, resolvedColorScheme)
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
    }

    private var sidebar: some View {
        AppSidebar(
            activeSaveID: $session.activeSaveID,
            liveTimerSaveID: session.liveTimerSaveID,
            isInGame: session.isInGame,
            saveSlots: session.saveSlots,
            liveTimer: session.puzzleTimer,
            onNewGame: handleNewGameFromSidebar,
            onSelectSave: selectSaveFromSidebar,
            onArchiveSave: session.archiveSave,
            onDeleteSave: session.deleteSave,
            savePendingArchive: $modals.pendingArchiveSave,
            pendingProgressReset: $modals.pendingProgressReset
        )
    }

    private var detailColumn: some View {
        let isInGame = session.isInGame
        let isLoadingPuzzle = session.isLoadingPuzzle
        return ZStack {
            homeView
                .opacity(isInGame || isLoadingPuzzle ? 0 : 1)
                .allowsHitTesting(!isInGame && !isLoadingPuzzle)
            if let game = session.game, session.activeSaveID != nil {
                GamePlayView(
                    game: game,
                    timer: session.puzzleTimer,
                    onGoHome: goHome,
                    onEscape: handleEscape,
                    showSettings: $showSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isInGame && !isLoadingPuzzle ? 1 : 0)
                .allowsHitTesting(isInGame && !isLoadingPuzzle)
            }
            if isLoadingPuzzle {
                LoadingPuzzleSkeleton()
                    .transition(.opacity)
            }
        }
        .animation(GameSessionModel.navigationAnimation, value: isInGame)
        .animation(.easeInOut(duration: 0.2), value: isLoadingPuzzle)
        .overlay {
            GameOverlayHost(
                phase: gameOverlayPhase,
                achievements: session.activeCelebrations,
                formattedElapsed: session.puzzleTimer.formattedElapsed,
                buttonTint: appAccent.prominentTint,
                colorScheme: resolvedColorScheme,
                onDismissAchievement: session.dismissCelebration,
                onDismissPuzzleEnd: session.dismissPuzzleEndBanner,
                onEndGameAction: {
                    session.dismissPuzzleEndBanner()
                    goHome()
                }
            )
        }
        .overlay {
            DetailModalOverlay(
                modals: $modals,
                session: session,
                customPuzzlePrep: customPuzzlePrep,
                colorScheme: resolvedColorScheme,
                onStartCustomPuzzle: startCustomPuzzle
            )
        }
        .toolbar {
            DetailToolbar(
                gameOutcome: isInGame ? session.game?.outcome : nil,
                timer: session.puzzleTimer,
                isArchived: session.activeSaveMetadata?.isArchived == true,
                colorScheme: resolvedColorScheme,
                showSettings: $showSettings,
                onGoHome: goHome,
                onArchive: archiveActiveGame,
                onRestart: restartActiveGame,
                onToggleSidebar: toggleSidebar
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hiddenWindowToolbar()
    }

    private var homeView: some View {
        HomeView(
            onEasy: { session.startNewGame(difficulty: .easy) },
            onMedium: { session.startNewGame(difficulty: .medium) },
            onHard: { session.startNewGame(difficulty: .hard) },
            onFromSeed: presentCustomPuzzleSheet,
        )
        .navigationTitle("")
        .hiddenWindowToolbar()
        #if os(macOS)
        .background {
            if !session.isInGame {
                EscapeKeyboardHost(onEscape: handleEscape)
            }
        }
        #endif
    }

    /// Loading blocks win/loss; end banner is optional until dismissed (sidebar stays usable).
    private var gameOverlayPhase: GameOverlayPhase? {
        if session.isLoadingPuzzle { return nil }
        guard session.isPuzzleEndBannerVisible else { return nil }
        switch session.game?.outcome {
        case .won:
            return .puzzleEnd(PuzzleEndBannerView.Kind.won)
        case .lost:
            return .puzzleEnd(PuzzleEndBannerView.Kind.lost)
        default:
            return nil
        }
    }

    // MARK: - Actions

    private func goHome() {
        session.goHome()
        #if os(iOS)
        showSavesSheet = false
        #endif
    }

    private func selectSaveFromSidebar(id: UUID) {
        modals.dismissAll()
        session.selectSave(id: id)
        #if os(iOS)
        showSavesSheet = false
        #endif
    }

    private func handleNewGameFromSidebar() {
        modals.dismissAll()
        #if os(iOS)
        showSavesSheet = false
        #endif
        if session.isInGame {
            goHome()
        } else {
            session.startNewGame(difficulty: session.lastFocusedDifficulty)
        }
    }

    private func presentCustomPuzzleSheet() {
        let fallback = session.lastFocusedDifficulty
        if let prefill = PuzzleSeed.prefillFromClipboard(defaultDifficulty: fallback) {
            modals.customPuzzle = CustomPuzzleDraft(seedInput: prefill.text, difficulty: prefill.difficulty)
        } else {
            modals.customPuzzle = CustomPuzzleDraft(seedInput: "", difficulty: fallback)
        }
    }

    private func startCustomPuzzle() {
        guard let seed = customPuzzlePrep.readySeed,
              let template = customPuzzlePrep.readyTemplate else { return }
        modals.customPuzzle = nil
        session.startCustomPuzzle(seed: seed, template: template)
    }

    private func archiveActiveGame() {
        guard let game = session.game else { return }
        if game.outcome.requiresArchiveConfirmation {
            modals.confirmsGameArchive = true
        } else if let saveID = session.activeSaveID {
            session.archiveSave(id: saveID)
        }
    }

    private func restartActiveGame() {
        guard let game = session.game else { return }
        if game.hasPlayerEntries {
            modals.confirmsGameRestart = true
        } else {
            session.restartCurrentPuzzle(game: game)
        }
    }

    /// Escape dismisses a modal, then settings, before the game view's own handling.
    private func handleEscape() -> Bool {
        if modals.isPresented {
            modals.dismissAll()
            return true
        }
        if showSettings {
            showSettings = false
            return true
        }
        return false
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

    // MARK: - Lifecycle

    private func performInitialSetup() {
        #if os(macOS)
        columnVisibility = .all
        #endif
        syncSystemColorSchemeFromPlatform()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        session.start()
        #if os(macOS)
        isAppActive = NSApp.isActive
        #else
        isAppActive = scenePhase == .active
        #endif
        session.updateDockIcon()
    }

    private var shouldHoldAutoPause: Bool {
        !isAppActive || showSettings || isWindowMiniaturized
    }

    /// Avoid pausing/resuming the timer during an in-flight SwiftUI layout pass.
    private func scheduleAutoPauseInterruptUpdate() {
        Task { @MainActor in
            session.updateAutoPause(hold: shouldHoldAutoPause)
        }
    }

    private func handleSystemThemeDidChange() {
        guard appearanceMode == .system else { return }
        refreshAppearanceFromSettings()
    }

    private func refreshAppearanceFromSettings() {
        syncSystemColorSchemeFromPlatform()
        appAccent.systemColorScheme = systemColorScheme
        appAccent.refresh()
        session.updateDockIcon()
        #if os(macOS)
        if appearanceMode == .system {
            Task { @MainActor in
                syncSystemColorSchemeFromPlatform()
                appAccent.systemColorScheme = systemColorScheme
                appAccent.refresh()
                session.updateDockIcon()
            }
        }
        #endif
    }

    private func syncSystemColorSchemeFromPlatform() {
        systemColorScheme = AppearanceMode.systemColorScheme()
    }
}
