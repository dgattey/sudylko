import XCTest
@testable import Sudylko

final class AchievementStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AchievementStore.resetAllProgress()
    }

    override func tearDown() {
        AchievementStore.resetAllProgress()
        super.tearDown()
    }

    func testDisplayOrderListsEveryAchievement() {
        XCTAssertEqual(AchievementID.displayOrder.count, 17)
        XCTAssertEqual(Set(AchievementID.displayOrder.map(\.rawValue)).count, 17)
    }

    func testFirstGameOnStart() {
        let id = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        XCTAssertEqual(id, .firstGame)
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.firstGame.rawValue))
    }

    func testFirstVictoryAndDifficultyWins() {
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let unlocked = win(
            difficulty: .easy,
            elapsed: 400,
            mistakes: 0,
            customSeed: false,
            usedNotes: false
        )
        XCTAssertTrue(unlocked.contains(.firstVictory))
        XCTAssertTrue(unlocked.contains(.easyWin))
        XCTAssertFalse(unlocked.contains(.mediumWin))
        XCTAssertFalse(unlocked.contains(.hardWin))
    }

    func testSpeedRunAndMarathonThresholds() {
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let fast = win(elapsed: 299, mistakes: 0)
        XCTAssertTrue(fast.contains(.speedRun))

        AchievementStore.resetAllProgress()
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let slow = win(elapsed: 1_200, mistakes: 0)
        XCTAssertTrue(slow.contains(.marathon))
        XCTAssertFalse(slow.contains(.speedRun))
    }

    func testSeedSolverRequiresCustomSeed() {
        _ = AchievementStore.recordGameStarted(difficulty: .medium, fromCustomSeed: true)
        let unlocked = win(difficulty: .medium, elapsed: 400, mistakes: 0, customSeed: true)
        XCTAssertTrue(unlocked.contains(.seedSolver))
    }

    func testVictoryMilestones() {
        for _ in 0..<5 {
            _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
            _ = win(elapsed: 400, mistakes: 0)
        }
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.fiveVictories.rawValue))

        for _ in 0..<5 {
            _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
            _ = win(elapsed: 400, mistakes: 0)
        }
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.tenVictories.rawValue))
    }

    func testMistakeBasedWinAchievements() {
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let clean = win(mistakes: 0)
        XCTAssertTrue(clean.contains(.cleanSheet))

        AchievementStore.resetAllProgress()
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let rough = win(mistakes: 5)
        XCTAssertTrue(rough.contains(.roughDraft))

        AchievementStore.resetAllProgress()
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let danger = win(mistakes: 8)
        XCTAssertTrue(danger.contains(.livingDangerously))
    }

    func testMistakeHundredLifetime() {
        for _ in 0..<100 {
            AchievementStore.recordMistake(difficulty: .easy)
        }
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.mistakeHundred.rawValue))
    }

    func testAbandonedOnce() {
        let id = AchievementStore.recordAbandonedSave(difficulty: .hard)
        XCTAssertEqual(id, .abandonedOnce)
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.abandonedOnce.rawValue))
    }

    func testTrifectaAcrossDifficulties() {
        for difficulty in [GameDifficulty.easy, .medium, .hard] {
            _ = AchievementStore.recordGameStarted(difficulty: difficulty, fromCustomSeed: false)
            _ = win(difficulty: difficulty, elapsed: 400, mistakes: 0)
        }
        XCTAssertTrue(AchievementStore.unlockedIDs().contains(AchievementID.trifecta.rawValue))
    }

    func testPencilPusherRequiresNotes() {
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        let unlocked = win(usedNotes: true)
        XCTAssertTrue(unlocked.contains(.pencilPusher))
    }

    func testRecordCompletionDoesNotDoubleCount() {
        _ = AchievementStore.recordGameStarted(difficulty: .easy, fromCustomSeed: false)
        var save = makeSave(outcome: .won)
        let first = AchievementStore.recordCompletion(
            AchievementCompletionContext(save: save),
            save: save
        )
        XCTAssertFalse(first.isEmpty)
        save.statsCompletionRecorded = true
        let second = AchievementStore.recordCompletion(
            AchievementCompletionContext(save: save),
            save: save
        )
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(AchievementStore.loadStats().completionCount, 1)
    }

    func testSavedGameRoundTripsMistakeCount() throws {
        let save = makeSave(mistakes: 7, outcome: .playing)
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(SavedGameState.self, from: data)
        XCTAssertEqual(decoded.mistakesThisPuzzle, 7)
    }

    // MARK: - Helpers

    @discardableResult
    private func win(
        difficulty: GameDifficulty = .easy,
        elapsed: Double = 400,
        mistakes: Int = 0,
        customSeed: Bool = false,
        usedNotes: Bool = false
    ) -> [AchievementID] {
        let save = makeSave(
            difficulty: difficulty,
            elapsed: elapsed,
            mistakes: mistakes,
            customSeed: customSeed,
            usedNotes: usedNotes,
            outcome: .won
        )
        let context = AchievementCompletionContext(
            difficulty: difficulty,
            elapsedSeconds: elapsed,
            startedFromCustomSeed: customSeed,
            mistakesInPuzzle: mistakes,
            usedNotes: usedNotes
        )
        return AchievementStore.recordCompletion(context, save: save)
    }

    private func makeSave(
        difficulty: GameDifficulty = .easy,
        elapsed: Double = 400,
        mistakes: Int = 0,
        customSeed: Bool = false,
        usedNotes: Bool = false,
        outcome: PuzzleOutcome = .won
    ) -> SavedGameState {
        let solution = Array(repeating: Array(repeating: 1, count: 9), count: 9)
        let notes: [[[Int]]] = usedNotes
            ? {
                var grid = Array(repeating: Array(repeating: [Int](), count: 9), count: 9)
                grid[0][0] = [2]
                return grid
            }()
            : Array(repeating: Array(repeating: [Int](), count: 9), count: 9)
        let now = Date()
        return SavedGameState(
            id: UUID(),
            difficulty: difficulty,
            puzzleNumber: 1,
            startedFromCustomSeed: customSeed,
            values: solution.map { $0.map { Optional($0) } },
            notes: notes,
            isPencilMode: false,
            selectedRow: nil,
            selectedCol: nil,
            highlightedDigit: nil,
            outcome: outcome,
            mistakesThisPuzzle: mistakes,
            statsCompletionRecorded: false,
            elapsedSeconds: elapsed,
            timerPaused: true,
            timerRunning: false,
            createdAt: now,
            savedAt: now,
            storedSolution: solution,
            givenCells: [CellIndex(row: 0, col: 0)]
        )
    }
}
