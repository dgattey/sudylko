import Observation
import SwiftUI

/// The window's play session: which save is open, its live game and timer, the sidebar's save
/// list, and the achievement celebrations it unlocks. `ContentView` owns the window chrome and
/// modals and forwards platform events (activity, settings, appearance) here.
@Observable
@MainActor
final class GameSessionModel {
    private enum Keys {
        static let lastDifficulty = "lastDifficulty"
        static let lastFocusedSaveID = "lastFocusedSaveID"
        static let revealMistakesImmediately = "revealMistakesImmediately"
        static let impossibleMode = "impossibleMode"
    }

    static let navigationAnimation: Animation = .easeInOut(duration: 0.25)

    private(set) var game: GameViewModel?
    /// Bound by the sidebar; `ContentView` routes changes to `handleActiveSaveIDChange`.
    var activeSaveID: UUID?
    /// Avoids re-reading the active save from disk when persisting on switch.
    private(set) var activeSaveMetadata: SavePersistMetadata?
    private(set) var saveSlots: [SaveSlotSummary] = []
    private(set) var activeCelebrations: [AchievementID] = []
    private(set) var isLoadingPuzzle = false
    private(set) var isPuzzleEndBannerVisible = false

    let puzzleTimer = PuzzleTimer()

    @ObservationIgnored private let appAccent: AppAccentModel
    @ObservationIgnored private let randomPuzzlePrep = RandomPuzzlePrepCache()
    @ObservationIgnored private var celebrationQueue: [[AchievementID]] = []
    @ObservationIgnored private var autoPausedForInactive = false
    @ObservationIgnored private var saveLoadTask: Task<Void, Never>?

    init(appAccent: AppAccentModel) {
        self.appAccent = appAccent
    }

    var isInGame: Bool {
        game != nil && activeSaveID != nil
    }

    /// Save the live timer reflects; nil while switching or before restore finishes.
    var liveTimerSaveID: UUID? {
        guard isInGame,
              let id = activeSaveID,
              lastFocusedSaveIDString == id.uuidString
        else { return nil }
        return id
    }

    var lastFocusedDifficulty: GameDifficulty {
        GameDifficulty(rawValue: UserDefaults.standard.string(forKey: Keys.lastDifficulty) ?? "") ?? .medium
    }

    private var lastFocusedSaveIDString: String {
        get { UserDefaults.standard.string(forKey: Keys.lastFocusedSaveID) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastFocusedSaveID) }
    }

    private func setLastDifficulty(_ difficulty: GameDifficulty) {
        UserDefaults.standard.set(difficulty.rawValue, forKey: Keys.lastDifficulty)
    }

    // MARK: - Launch

    func start() {
        refreshSaveSlotsInBackground()
        randomPuzzlePrep.schedulePrepForAllDifficulties()
        Task {
            if let id = UUID(uuidString: lastFocusedSaveIDString),
               await Task.detached(priority: .utility) { SaveLoadWork.load(id: id) }.value == nil {
                lastFocusedSaveIDString = ""
            }
            await restoreLastSessionIfNeeded()
        }
    }

    private func restoreLastSessionIfNeeded() async {
        guard !isInGame else { return }
        guard let id = UUID(uuidString: lastFocusedSaveIDString) else { return }
        let state = await Task.detached(priority: .utility) {
            SaveLoadWork.load(id: id)
        }.value
        guard let state, state.outcome == .playing else { return }
        await performSaveSwitch(to: id)
    }

    // MARK: - Starting and leaving games

    func startNewGame(difficulty: GameDifficulty) {
        pauseAndPersistOutgoingGame()
        setLastDifficulty(difficulty)

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

    func startCustomPuzzle(seed: PuzzleSeed, template: GeneratedPuzzle) {
        pauseAndPersistOutgoingGame()
        setLastDifficulty(seed.difficulty)
        beginNewGame(
            puzzleSeed: seed,
            startedFromCustomSeed: true,
            preparedTemplate: template
        )
    }

    func goHome() {
        pauseAndPersistOutgoingGame()
        withAnimation(Self.navigationAnimation) {
            clearActiveGameState()
        }
    }

    func restartCurrentPuzzle(game: GameViewModel) {
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
        persistGameplaySession()
    }

    private func assignGame(_ newGame: GameViewModel?) {
        game = newGame
        isPuzzleEndBannerVisible = newGame?.outcome.isEnded ?? false
    }

    private func clearActiveGameState() {
        assignGame(nil)
        activeSaveID = nil
        activeSaveMetadata = nil
        puzzleTimer.reset()
        updateDockIcon()
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

    private func beginNewGameAsync(
        puzzleSeed: PuzzleSeed,
        startedFromCustomSeed: Bool,
        preparedTemplate: GeneratedPuzzle? = nil
    ) async {
        let needsGeneration = preparedTemplate == nil
        if needsGeneration {
            isLoadingPuzzle = true
        }
        defer {
            if needsGeneration {
                isLoadingPuzzle = false
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
        withAnimation(Self.navigationAnimation) {
            assignGame(newGame)
            activeSaveID = saveID
        }
        applyGameplaySettingsToActiveGame()
        puzzleTimer.start()
        updateDockIcon()
        randomPuzzlePrep.schedulePrepForAllDifficulties()
    }

    // MARK: - Switching saves

    /// Sidebar row selection — routes through `activeSaveID` so loading uses one code path.
    func selectSave(id: UUID) {
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

    func handleActiveSaveIDChange(from oldID: UUID?, to newID: UUID?) {
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

    private func switchToSave(id: UUID) {
        saveLoadTask?.cancel()
        saveLoadTask = Task {
            await performSaveSwitch(to: id)
        }
    }

    private func performSaveSwitch(to id: UUID) async {
        if game != nil, lastFocusedSaveIDString == id.uuidString {
            resumeLoadedGameIfNeeded()
            return
        }

        isLoadingPuzzle = true
        defer { isLoadingPuzzle = false }

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
        setLastDifficulty(state.difficulty)

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
        withAnimation(Self.navigationAnimation) {
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

    // MARK: - Persistence

    /// Snapshots the in-memory game for disk without blocking on unrelated saves.
    private func captureOutgoingSave(excluding excludedID: UUID? = nil) -> SavedGameState? {
        guard let outgoingID = activeSaveID,
              outgoingID != excludedID,
              let game,
              isInGame else { return nil }
        guard let metadata = activeSaveMetadata else { return nil }
        return SavedGameState.from(
            id: outgoingID,
            game: game,
            timer: puzzleTimer,
            metadata: metadata
        )
    }

    private func pauseAndPersistOutgoingGame() {
        if let game, !game.isPuzzleEnded,
           puzzleTimer.isRunning, !puzzleTimer.isPaused {
            puzzleTimer.pause()
        }
        guard let state = captureOutgoingSave() else { return }
        SaveLoadWork.enqueueSave(state)
        refreshSaveSlotsInBackground()
    }

    /// Board, outcome, and session chrome (pencil mode, selection, timer) for the active save.
    func persistActiveGame() {
        guard let state = captureOutgoingSave() else { return }
        SaveLoadWork.enqueueSave(state)
    }

    /// Timer pause/background also refreshes sidebar elapsed times.
    func persistGameplaySession() {
        persistActiveGame()
        refreshSaveSlotsInBackground()
    }

    private func refreshSaveSlotsInBackground() {
        Task.detached(priority: .utility) {
            let slots = SaveLoadWork.summaries()
            await MainActor.run {
                self.saveSlots = slots
            }
        }
    }

    // MARK: - Save management

    func handleSavesDidChange(_ notification: Notification) {
        if notification.object as? SavesChangeReason == .deleteAll {
            lastFocusedSaveIDString = ""
            if isInGame {
                goHome()
            }
        }
        refreshSaveSlotsInBackground()
    }

    func deleteSave(id: UUID) {
        let wasActiveGame = activeSaveID == id && isInGame
        if lastFocusedSaveIDString == id.uuidString {
            lastFocusedSaveIDString = ""
        }
        SaveLoadWork.delete(id: id)
        if wasActiveGame {
            withAnimation(Self.navigationAnimation) {
                clearActiveGameState()
            }
        }
        refreshSaveSlotsInBackground()
    }

    func archiveSave(id: UUID) {
        let isCurrentGame = activeSaveID == id && isInGame

        Task.detached(priority: .utility) {
            if let state = SaveLoadWork.load(id: id),
               !state.isArchived,
               state.outcome == .playing,
               let abandoned = AchievementStore.recordAbandonedSave(difficulty: state.difficulty) {
                await MainActor.run {
                    self.enqueueCelebrations([abandoned])
                }
            }
            SaveLoadWork.archive(id: id)
            await MainActor.run {
                if self.lastFocusedSaveIDString == id.uuidString {
                    self.lastFocusedSaveIDString = ""
                }
                self.refreshSaveSlotsInBackground()
                guard isCurrentGame else { return }
                withAnimation(Self.navigationAnimation) {
                    self.clearActiveGameState()
                }
            }
        }
    }

    /// Resets progress defaults, then performs any save-file side effects that need active-game cleanup.
    func performProgressReset(_ kind: ProgressResetKind) {
        ProgressResetKind.perform(kind)
        switch kind {
        case .all:
            SaveLoadWork.deleteAll()
        case .archivedGames:
            deleteArchivedSaves()
        case .statistics, .achievements:
            break
        }
    }

    private func deleteArchivedSaves() {
        let activeIsArchived = isInGame
            && (saveSlots.first { $0.id == activeSaveID }?.isArchived ?? false)
        if activeIsArchived, let activeSaveID {
            if lastFocusedSaveIDString == activeSaveID.uuidString {
                lastFocusedSaveIDString = ""
            }
            withAnimation(Self.navigationAnimation) {
                clearActiveGameState()
            }
        }
        SaveLoadWork.deleteArchived()
        refreshSaveSlotsInBackground()
    }

    // MARK: - Outcome, stats, and celebrations

    func outcomeChanged(from old: PuzzleOutcome?, to new: PuzzleOutcome?) {
        handleOutcomeChange(from: old, to: new)
        if new == .won || new == .lost {
            isPuzzleEndBannerVisible = true
        } else if new == .playing {
            isPuzzleEndBannerVisible = false
        }
    }

    func dismissPuzzleEndBanner() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPuzzleEndBannerVisible = false
        }
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

    /// Achievements unlocked by a single event are shown together in one modal; separate
    /// events queue as their own batches.
    func enqueueCelebrations(_ ids: [AchievementID]) {
        guard !ids.isEmpty else { return }
        let ordered = AchievementID.displayOrder.filter(ids.contains)
        celebrationQueue.append(ordered)
        presentNextCelebration()
    }

    func dismissCelebration() {
        activeCelebrations = []
        presentNextCelebration()
    }

    private func presentNextCelebration() {
        guard activeCelebrations.isEmpty, !celebrationQueue.isEmpty else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            activeCelebrations = celebrationQueue.removeFirst()
        }
    }

    // MARK: - Settings, activity, and Dock

    func applyGameplaySettingsToActiveGame() {
        game?.revealMistakesImmediately = UserDefaults.standard.bool(forKey: Keys.revealMistakesImmediately)
        game?.impossibleMode = UserDefaults.standard.bool(forKey: Keys.impossibleMode)
        game?.refreshMistakes()
    }

    func appActivityChanged(isActive: Bool, holdAutoPause: Bool) {
        if !isActive {
            persistGameplaySession()
        }
        updateAutoPause(hold: holdAutoPause)
        updateDockIcon()
    }

    /// Pauses the running puzzle while the app is inactive, settings are open, or the window is
    /// minimized, and resumes only a pause it started itself.
    func updateAutoPause(hold: Bool) {
        if hold {
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

    func updateDockIcon() {
        let inGame = isInGame
        let showPaused = inGame && puzzleTimer.isPaused
        let timerText: String? = inGame && !showPaused && puzzleTimer.isRunning
            ? puzzleTimer.formattedElapsed
            : nil
        DockIconRenderer.updateDockIcon(
            accent: appAccent.accent,
            colorScheme: appAccent.resolvedColorScheme,
            inGame: inGame,
            showPaused: showPaused,
            timerText: timerText
        )
    }
}
