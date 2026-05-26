import Foundation

enum AchievementID: String, Codable, Identifiable {
    case firstVictory
    case easyWin
    case mediumWin
    case hardWin
    case speedRun
    case seedSolver
    case fiveVictories
    case tenVictories
    case firstGame
    case marathon
    case cleanSheet
    case roughDraft
    case mistakeHundred
    case abandonedOnce
    case trifecta
    case pencilPusher
    case livingDangerously

    var id: String { rawValue }

    /// Easier / earlier achievements first (debug menu and home list).
    static let displayOrder: [AchievementID] = [
        .firstGame,
        .firstVictory,
        .easyWin,
        .mediumWin,
        .hardWin,
        .seedSolver,
        .fiveVictories,
        .tenVictories,
        .speedRun,
        .marathon,
        .cleanSheet,
        .pencilPusher,
        .roughDraft,
        .livingDangerously,
        .abandonedOnce,
        .mistakeHundred,
        .trifecta,
    ]

    var title: String {
        switch self {
        case .firstVictory: "First Victory"
        case .easyWin: "Easy Does It"
        case .mediumWin: "Middle Ground"
        case .hardWin: "Hard Mode"
        case .speedRun: "Against the Clock"
        case .seedSolver: "Seed Solver"
        case .fiveVictories: "Dedicated"
        case .tenVictories: "Veteran"
        case .firstGame: "New Grid"
        case .marathon: "Marathon"
        case .cleanSheet: "Spotless"
        case .roughDraft: "Learning Curve"
        case .mistakeHundred: "Typo King"
        case .abandonedOnce: "Walk Away"
        case .trifecta: "Trifecta"
        case .pencilPusher: "Pencil Pusher"
        case .livingDangerously: "By the Skin"
        }
    }

    var subtitle: String {
        switch self {
        case .firstVictory: "Complete your first puzzle"
        case .easyWin: "Finish an Easy puzzle"
        case .mediumWin: "Finish a Medium puzzle"
        case .hardWin: "Finish a Hard puzzle"
        case .speedRun: "Finish in under five minutes"
        case .seedSolver: "Complete a puzzle from a custom seed"
        case .fiveVictories: "Complete five puzzles"
        case .tenVictories: "Complete ten puzzles"
        case .firstGame: "Start a new game"
        case .marathon: "Finish in twenty minutes or more"
        case .cleanSheet: "Finish with zero mistakes"
        case .roughDraft: "Finish one puzzle with five or more mistakes"
        case .mistakeHundred: "Make one hundred mistakes total"
        case .abandonedOnce: "Delete an in-progress saved game"
        case .trifecta: "Complete Easy, Medium, and Hard"
        case .pencilPusher: "Win after using pencil notes"
        case .livingDangerously: "Win a puzzle with eight or more mistakes"
        }
    }

    var systemImage: String {
        switch self {
        case .firstVictory: "star.fill"
        case .easyWin: "leaf.fill"
        case .mediumWin: "circle.hexagongrid.fill"
        case .hardWin: "flame.fill"
        case .speedRun: "bolt.fill"
        case .seedSolver: "number"
        case .fiveVictories: "trophy.fill"
        case .tenVictories: "rosette"
        case .firstGame: "plus.circle.fill"
        case .marathon: "hourglass"
        case .cleanSheet: "sparkles"
        case .roughDraft: "eraser.fill"
        case .mistakeHundred: "exclamationmark.bubble.fill"
        case .abandonedOnce: "door.left.hand.open"
        case .trifecta: "square.grid.3x3.fill"
        case .pencilPusher: "pencil.and.outline"
        case .livingDangerously: "heart.slash.fill"
        }
    }
}

struct AchievementCompletionContext: Equatable {
    let difficulty: GameDifficulty
    let elapsedSeconds: Double
    let startedFromCustomSeed: Bool
    let mistakesInPuzzle: Int
    let usedNotes: Bool
}

enum AchievementStore {
    private static let unlockedKey = "achievementUnlockedIDs"

    static func unlockedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: unlockedKey) ?? [])
    }

    static func loadStats() -> PlayerLifetimeStats {
        PlayerStatsStore.load()
    }

    private static func saveStats(_ stats: PlayerLifetimeStats) {
        PlayerStatsStore.save(stats)
    }

    @discardableResult
    static func unlock(_ id: AchievementID) -> Bool {
        var ids = unlockedIDs()
        guard ids.insert(id.rawValue).inserted else { return false }
        UserDefaults.standard.set(Array(ids), forKey: unlockedKey)
        NotificationCenter.default.post(name: .achievementsDidChange, object: nil)
        return true
    }

    static func resetUnlocks() {
        UserDefaults.standard.removeObject(forKey: unlockedKey)
        NotificationCenter.default.post(name: .achievementsDidChange, object: nil)
    }

    static func resetStats() {
        PlayerStatsStore.reset()
    }

    static func recordGameStarted(difficulty: GameDifficulty, fromCustomSeed: Bool) -> AchievementID? {
        var stats = loadStats()
        stats.recordStarted(difficulty: difficulty, fromCustomSeed: fromCustomSeed)
        saveStats(stats)
        if stats.gamesStartedCount >= 1, unlock(.firstGame) {
            return .firstGame
        }
        return nil
    }

    static func recordMistake(difficulty: GameDifficulty) {
        var stats = loadStats()
        stats.recordMistake(difficulty: difficulty)
        saveStats(stats)
        if stats.lifetimeMistakes >= 100 {
            _ = unlock(.mistakeHundred)
        }
    }

    static func recordAbandonedSave(difficulty: GameDifficulty) -> AchievementID? {
        var stats = loadStats()
        stats.recordLoss(difficulty: difficulty)
        saveStats(stats)
        if stats.abandonedSaves >= 1, unlock(.abandonedOnce) {
            return .abandonedOnce
        }
        return nil
    }

    /// Records a finished puzzle into lifetime stats, then returns newly unlocked achievements.
    static func recordCompletion(_ context: AchievementCompletionContext) -> [AchievementID] {
        var stats = loadStats()
        stats.recordWin(
            difficulty: context.difficulty,
            elapsedSeconds: context.elapsedSeconds,
            mistakesInPuzzle: context.mistakesInPuzzle,
            fromCustomSeed: context.startedFromCustomSeed
        )
        saveStats(stats)
        return newlyUnlocked(for: context, stats: stats)
    }

    static func newlyUnlocked(
        for context: AchievementCompletionContext,
        stats: PlayerLifetimeStats? = nil
    ) -> [AchievementID] {
        let stats = stats ?? loadStats()
        var unlocked: [AchievementID] = []

        func tryUnlock(_ id: AchievementID, when condition: Bool) {
            guard condition, unlock(id) else { return }
            unlocked.append(id)
        }

        tryUnlock(.firstVictory, when: stats.completionCount >= 1)
        tryUnlock(.easyWin, when: context.difficulty == .easy)
        tryUnlock(.mediumWin, when: context.difficulty == .medium)
        tryUnlock(.hardWin, when: context.difficulty == .hard)
        tryUnlock(.speedRun, when: context.elapsedSeconds < 300)
        tryUnlock(.seedSolver, when: context.startedFromCustomSeed)
        tryUnlock(.fiveVictories, when: stats.completionCount >= 5)
        tryUnlock(.tenVictories, when: stats.completionCount >= 10)
        tryUnlock(.marathon, when: context.elapsedSeconds >= 1_200)
        tryUnlock(.cleanSheet, when: context.mistakesInPuzzle == 0)
        tryUnlock(.roughDraft, when: context.mistakesInPuzzle >= 5)
        tryUnlock(.livingDangerously, when: context.mistakesInPuzzle >= 8)
        tryUnlock(.mistakeHundred, when: stats.lifetimeMistakes >= 100)
        tryUnlock(.abandonedOnce, when: stats.abandonedSaves >= 1)
        tryUnlock(.trifecta, when: stats.completedEasy && stats.completedMedium && stats.completedHard)
        tryUnlock(.pencilPusher, when: context.usedNotes)

        return unlocked
    }

    #if DEBUG
    @discardableResult
    static func debugUnlock(_ id: AchievementID) -> Bool {
        unlock(id)
    }
    #endif
}
